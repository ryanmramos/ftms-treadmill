import Toybox.Lang;
import Toybox.BluetoothLowEnergy;

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
    private var _scanCandidates as Array<FtmsScanCandidate>;
    private var _selectedIdentity as String?;
    private var _selectedScanResult as BluetoothLowEnergy.ScanResult?;

    private var _parser as FtmsParser;
    private var _recordAssembler as FtmsRecordAssembler;
    private var _latestSample as FtmsSample?;
    private var _lastValidSampleAtMs as Number?;
    private var _retryAttempt as Number;
    private var _connectionAlerted as Boolean;
    private var _lostAlertCount as Number;
    private var _restoredAlertCount as Number;

    function initialize(transport as FtmsTransport) {
        _state = STATE_UNCONFIGURED;
        _transport = transport;
        _transport.setListener(self);
        _scheduler = null;
        _scanCandidates = [];
        _selectedIdentity = null;
        _selectedScanResult = null;
        _parser = new FtmsParser();
        _recordAssembler = new FtmsRecordAssembler();
        _latestSample = null;
        _lastValidSampleAtMs = null;
        _retryAttempt = 0;
        _connectionAlerted = false;
        _lostAlertCount = 0;
        _restoredAlertCount = 0;
    }

    function setScheduler(scheduler as FtmsScheduler) as Void {
        _scheduler = scheduler;
        _scheduler.setListener(self);
    }

    function getState() as Number {
        return _state;
    }

    function getScanCandidates() as Array<FtmsScanCandidate> {
        return _scanCandidates;
    }

    function selectCandidate(identity as String) as Boolean {
        for (var i = 0; i < _scanCandidates.size(); i += 1) {
            var candidate = _scanCandidates[i];

            if (candidate.identity.equals(identity)) {
                _selectedIdentity = identity;
                _selectedScanResult = candidate.scanResult;
                _state = STATE_CONNECTING;
                _retryAttempt = 0;
                cancelScheduledWork();
                _transport.stopScan();
                _transport.connect(identity, _selectedScanResult);
                return true;
            }
        }

        return false;
    }

    function getSelectedIdentity() as String? {
        return _selectedIdentity;
    }

    function getSelectedScanResult() as BluetoothLowEnergy.ScanResult? {
        return _selectedScanResult;
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

    function getLostAlertCount() as Number {
        return _lostAlertCount;
    }

    function getRestoredAlertCount() as Number {
        return _restoredAlertCount;
    }

    function beginScan() as Void {
        cancelScheduledWork();
        _transport.startScan();
        _state = STATE_SCANNING;
    }

    function stop() as Void {
        cancelScheduledWork();
        _recordAssembler.discard();
        _transport.stopScan();
        _transport.disconnect();
        _state = STATE_UNCONFIGURED;
        _lastValidSampleAtMs = null;
    }

    function onScanResult(
        identity as String,
        name as String?,
        rssi as Number,
        scanResult as BluetoothLowEnergy.ScanResult?
    ) as Void {
        if (_state != STATE_SCANNING) {
            return;
        }

        // The string is a simulator key only. Production transports must pass
        // the ScanResult and use it for isSameDevice-based matching.
        for (var i = 0; i < _scanCandidates.size(); i += 1) {
            var candidate = _scanCandidates[i];

            if (candidate.identity.equals(identity)) {
                candidate.name = name;
                candidate.rssi = rssi;
                candidate.scanResult = scanResult;
                return;
            }
        }

        _scanCandidates.add(new FtmsScanCandidate(
            identity,
            name,
            rssi,
            scanResult
        ));
    }

    function onConnected() as Void {
        cancelScheduledWork();
        _state = STATE_DISCOVERING;
        _transport.discoverTreadmillData();
    }

    function onConnectionFailed(reason as String) as Void {
        enterBackoff();
    }

    function onSubscribed() as Void {
        _state = STATE_SUBSCRIBING;
        _lastValidSampleAtMs = null;
    }

    function onTreadmillDataDiscovered() as Void {
        _state = STATE_SUBSCRIBING;
        _transport.subscribeTreadmillData();
    }

    function onTreadmillData(
        bytes as ByteArray,
        receivedAtMs as Number
    ) as Void {
        var record = _recordAssembler.append(bytes, receivedAtMs);

        if (record == null) {
            return;
        }

        // The current parser consumes one complete characteristic value. A
        // multi-notification record is recognized and held at this boundary;
        // field-level normalization is a separate transport step.
        if (!record.isSingleNotification()) {
            return;
        }

        var sample = _parser.parse(record.fragments[0], record.receivedAtMs);
        _latestSample = sample;

        // Warnings are diagnostic metadata. Only fatal parse errors or a
        // missing mandatory speed sample prevent readiness.
        if (sample.isValid() && sample.speedMps != null) {
            if (_connectionAlerted) {
                _restoredAlertCount += 1;
                _connectionAlerted = false;
            }

            _retryAttempt = 0;
            _lastValidSampleAtMs = receivedAtMs;
            _state = STATE_READY;
        }
    }

    function onDisconnected(reason as String?) as Void {
        _recordAssembler.discard();
        _lastValidSampleAtMs = null;

        if (!_connectionAlerted) {
            _lostAlertCount += 1;
            _connectionAlerted = true;
        }

        enterBackoff();
    }

    function onScheduledWork() as Void {
        if (_state != STATE_BACKOFF || _selectedIdentity == null) {
            return;
        }

        _transport.startScan();
        _state = STATE_SCANNING;
    }

    // The application timer calls this with a monotonic timestamp. Keeping
    // time outside the coordinator makes stale behavior deterministic in tests.
    function onTimerTick(nowMs as Number) as Void {
        if (_lastValidSampleAtMs == null) {
            return;
        }

        if (nowMs - _lastValidSampleAtMs >= FtmsConnectionPolicy.STALE_AFTER_MS &&
            (_state == STATE_READY || _state == STATE_SUBSCRIBING)) {
            _state = STATE_STALE;
        }
    }

    function retryDelayMsForCurrentAttempt() as Number {
        return FtmsConnectionPolicy.retryDelayMs(_retryAttempt);
    }

    private function enterBackoff() as Void {
        if (_selectedIdentity == null) {
            _state = STATE_UNCONFIGURED;
            return;
        }

        _state = STATE_BACKOFF;

        if (_scheduler != null) {
            _scheduler.schedule(
                FtmsConnectionPolicy.retryDelayMs(_retryAttempt)
            );
        }

        _retryAttempt += 1;
    }

    private function cancelScheduledWork() as Void {
        if (_scheduler != null) {
            _scheduler.cancel();
        }
    }
}
