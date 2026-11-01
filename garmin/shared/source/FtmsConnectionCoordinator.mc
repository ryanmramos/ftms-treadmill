import Toybox.Lang;

// receives coordinator edges. the data field maps state to its visual states
// and vibrates once per lost or restored alert.
typedef FtmsCoordinatorListener as interface {
    function onStateChanged(state as Number) as Void;
    function onConnectionLost() as Void;
    function onConnectionRestored() as Void;
};

// connection state machine for one selected treadmill. the transport and
// scheduler are injected, and the app passes a monotonic clock to onTimerTick,
// so every path runs in tests without hardware or sleeping.
class FtmsConnectionCoordinator {
    static const STATE_UNCONFIGURED = 0;
    static const STATE_SCANNING = 1;
    static const STATE_CONNECTING = 2;
    static const STATE_DISCOVERING = 3;
    static const STATE_SUBSCRIBING = 4;
    static const STATE_READY = 5;
    static const STATE_STALE = 6;
    static const STATE_BACKOFF = 7;

    private var _state as Number;
    private var _transport as FtmsTransport;
    private var _scheduler as FtmsScheduler?;
    private var _listener as FtmsCoordinatorListener?;
    private var _scanCandidates as Array<FtmsScanCandidate>;
    private var _selectedDevice as Object?;
    // true while a backoff scan is looking for the selected device
    private var _reconnecting as Boolean;

    private var _assembler as FtmsRecordAssembler;
    private var _latestSample as FtmsSample?;
    // last valid sample time, or the first tick after subscribing
    private var _staleClockStartMs as Number?;
    private var _retryAttempt as Number;
    // reached READY since selection; only then does a drop count as lost
    private var _wasLive as Boolean;
    private var _lostAlerted as Boolean;

    function initialize(transport as FtmsTransport) {
        _state = STATE_UNCONFIGURED;
        _transport = transport;
        _transport.setListener(self);
        _scheduler = null;
        _listener = null;
        _scanCandidates = [];
        _selectedDevice = null;
        _reconnecting = false;
        _assembler = new FtmsRecordAssembler();
        _latestSample = null;
        _staleClockStartMs = null;
        _retryAttempt = 0;
        _wasLive = false;
        _lostAlerted = false;
    }

    function setScheduler(scheduler as FtmsScheduler) as Void {
        _scheduler = scheduler;
        scheduler.setListener(self);
    }

    function setListener(listener as FtmsCoordinatorListener) as Void {
        _listener = listener;
    }

    function getState() as Number {
        return _state;
    }

    function getScanCandidates() as Array<FtmsScanCandidate> {
        return _scanCandidates;
    }

    function getSelectedDevice() as Object? {
        return _selectedDevice;
    }

    function getLatestSample() as FtmsSample? {
        return _latestSample;
    }

    function isDataAvailable() as Boolean {
        var sample = _latestSample;

        if (_state != STATE_READY || sample == null) {
            return false;
        }

        return sample.isValid() && sample.speedMps != null;
    }

    function retryDelayMsForCurrentAttempt() as Number {
        return FtmsConnectionPolicy.retryDelayMs(_retryAttempt);
    }

    // scan for the picker. starts a fresh candidate list.
    function beginScan() as Void {
        cancelScheduledWork();
        _reconnecting = false;
        _scanCandidates = [];
        _transport.startScan();
        setState(STATE_SCANNING);
    }

    // picks a scanned treadmill and connects to it
    function selectCandidate(device as Object) as Boolean {
        for (var i = 0; i < _scanCandidates.size(); i += 1) {
            var candidate = _scanCandidates[i];

            if (_transport.isSameDevice(candidate.device, device)) {
                _selectedDevice = candidate.device;
                _retryAttempt = 0;
                _wasLive = false;
                _lostAlerted = false;
                connectTo(candidate.device);
                return true;
            }
        }

        return false;
    }

    // resumes a treadmill saved from an earlier session: scans and connects
    // as soon as a scan result matches it, ignoring other FTMS devices
    function reconnectTo(device as Object) as Void {
        cancelScheduledWork();
        _selectedDevice = device;
        _scanCandidates = [];
        _retryAttempt = 0;
        _wasLive = false;
        _lostAlerted = false;
        _reconnecting = true;
        _transport.startScan();
        setState(STATE_SCANNING);
    }

    function stop() as Void {
        cancelScheduledWork();
        _assembler.discard();
        _reconnecting = false;
        _staleClockStartMs = null;
        // leave link states first so the disconnect echo from unpairing is ignored
        setState(STATE_UNCONFIGURED);
        _transport.stopScan();
        _transport.disconnect();
    }

    function onScanResult(
        device as Object,
        name as String?,
        rssi as Number
    ) as Void {
        if (_state != STATE_SCANNING) {
            return;
        }

        upsertCandidate(device, name, rssi);

        // during a reconnect scan only the selected treadmill is connected to;
        // other FTMS devices are listed but ignored
        var selected = _selectedDevice;

        if (_reconnecting && selected != null &&
            _transport.isSameDevice(selected, device)) {
            // keep the newest handle for the same treadmill
            _selectedDevice = device;
            connectTo(device);
        }
    }

    function onConnected() as Void {
        if (_state != STATE_CONNECTING) {
            return;
        }

        cancelScheduledWork();
        setState(STATE_DISCOVERING);
        _transport.discoverTreadmillData();
    }

    function onTreadmillDataDiscovered() as Void {
        if (_state != STATE_DISCOVERING) {
            return;
        }

        setState(STATE_SUBSCRIBING);
        _transport.subscribeTreadmillData();
    }

    // the stale clock already runs from the first tick in SUBSCRIBING, so a
    // confirmed subscription that never delivers data still goes stale
    function onSubscribed() as Void {
    }

    function onTreadmillData(
        bytes as ByteArray,
        receivedAtMs as Number
    ) as Void {
        if (_state != STATE_SUBSCRIBING && _state != STATE_READY &&
            _state != STATE_STALE) {
            return;
        }

        var sample = _assembler.append(bytes, receivedAtMs);

        if (sample == null) {
            return;
        }

        _latestSample = sample;

        // warnings are diagnostic metadata. only parse errors or a missing
        // speed keep the coordinator out of READY.
        if (!sample.isValid() || sample.speedMps == null) {
            return;
        }

        var restored = _lostAlerted;
        _retryAttempt = 0;
        _staleClockStartMs = receivedAtMs;
        _wasLive = true;
        _lostAlerted = false;
        setState(STATE_READY);

        var listener = _listener;

        if (restored && listener != null) {
            listener.onConnectionRestored();
        }
    }

    function onConnectionFailed(reason as String) as Void {
        if (!isLinkState()) {
            return;
        }

        _assembler.discard();
        enterBackoff();
        // drop the half-open link so it does not hold a pairing slot. the
        // disconnect echo arrives in BACKOFF and is ignored.
        _transport.disconnect();
    }

    function onDisconnected(reason as String?) as Void {
        if (!isLinkState()) {
            return;
        }

        _assembler.discard();

        var alert = _wasLive && !_lostAlerted;

        if (alert) {
            _lostAlerted = true;
        }

        enterBackoff();

        var listener = _listener;

        if (alert && listener != null) {
            listener.onConnectionLost();
        }
    }

    function onScheduledWork() as Void {
        if (_state != STATE_BACKOFF || _selectedDevice == null) {
            return;
        }

        _reconnecting = true;
        _transport.startScan();
        setState(STATE_SCANNING);
    }

    // the app calls this about once a second with System.getTimer()
    function onTimerTick(nowMs as Number) as Void {
        if (_state != STATE_SUBSCRIBING && _state != STATE_READY) {
            return;
        }

        var startMs = _staleClockStartMs;

        if (startMs == null) {
            _staleClockStartMs = nowMs;
            return;
        }

        if (nowMs - startMs >= FtmsConnectionPolicy.STALE_AFTER_MS) {
            setState(STATE_STALE);
        }
    }

    private function connectTo(device as Object) as Void {
        cancelScheduledWork();
        _reconnecting = false;
        _staleClockStartMs = null;
        _transport.stopScan();
        setState(STATE_CONNECTING);
        _transport.connect(device);
    }

    private function upsertCandidate(
        device as Object,
        name as String?,
        rssi as Number
    ) as Void {
        for (var i = 0; i < _scanCandidates.size(); i += 1) {
            var candidate = _scanCandidates[i];

            if (_transport.isSameDevice(candidate.device, device)) {
                candidate.device = device;
                candidate.name = name;
                candidate.rssi = rssi;
                return;
            }
        }

        _scanCandidates.add(new FtmsScanCandidate(device, name, rssi));
    }

    private function enterBackoff() as Void {
        if (_selectedDevice == null) {
            setState(STATE_UNCONFIGURED);
            return;
        }

        setState(STATE_BACKOFF);

        var scheduler = _scheduler;

        if (scheduler != null) {
            scheduler.schedule(FtmsConnectionPolicy.retryDelayMs(_retryAttempt));
        }

        _retryAttempt += 1;
    }

    // CONNECTING through STALE: a link exists or is being set up
    private function isLinkState() as Boolean {
        return _state >= STATE_CONNECTING && _state <= STATE_STALE;
    }

    private function setState(next as Number) as Void {
        if (next == _state) {
            return;
        }

        _state = next;

        var listener = _listener;

        if (listener != null) {
            listener.onStateChanged(next);
        }
    }

    private function cancelScheduledWork() as Void {
        var scheduler = _scheduler;

        if (scheduler != null) {
            scheduler.cancel();
        }
    }
}
