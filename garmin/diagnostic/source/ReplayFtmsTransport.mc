import Toybox.Lang;

// scripted transport for tests and replay. device handles are strings, and the
// emit functions play transport events into the coordinator.
class ReplayFtmsTransport {
    private var _listener as FtmsTransportListener?;
    private var _scanStarted as Boolean;
    private var _requestedDevice as Object?;
    private var _connectCount as Number;
    private var _disconnectCount as Number;
    private var _discoveryRequested as Boolean;
    private var _subscriptionRequested as Boolean;

    function initialize() {
        _listener = null;
        _scanStarted = false;
        _requestedDevice = null;
        _connectCount = 0;
        _disconnectCount = 0;
        _discoveryRequested = false;
        _subscriptionRequested = false;
    }

    function setListener(listener as FtmsTransportListener) as Void {
        _listener = listener;
    }

    function startScan() as Void {
        _scanStarted = true;
    }

    function stopScan() as Void {
        _scanStarted = false;
    }

    function connect(device as Object) as Void {
        _requestedDevice = device;
        _connectCount += 1;
    }

    function isSameDevice(a as Object, b as Object) as Boolean {
        return a.equals(b);
    }

    function discoverTreadmillData() as Void {
        _discoveryRequested = true;
    }

    function subscribeTreadmillData() as Void {
        _subscriptionRequested = true;
    }

    function disconnect() as Void {
        _disconnectCount += 1;
    }

    function wasScanStarted() as Boolean {
        return _scanStarted;
    }

    function wasDiscoveryRequested() as Boolean {
        return _discoveryRequested;
    }

    function wasSubscriptionRequested() as Boolean {
        return _subscriptionRequested;
    }

    function getRequestedDevice() as Object? {
        return _requestedDevice;
    }

    function getConnectCount() as Number {
        return _connectCount;
    }

    function getDisconnectCount() as Number {
        return _disconnectCount;
    }

    function emitScanResult(
        device as String,
        name as String?,
        rssi as Number
    ) as Void {
        if (_listener != null) {
            _listener.onScanResult(device, name, rssi);
        }
    }

    function emitConnected() as Void {
        if (_listener != null) {
            _listener.onConnected();
        }
    }

    function emitConnectionFailed(reason as String) as Void {
        if (_listener != null) {
            _listener.onConnectionFailed(reason);
        }
    }

    function emitTreadmillDataDiscovered() as Void {
        if (_listener != null) {
            _listener.onTreadmillDataDiscovered();
        }
    }

    function emitSubscribed() as Void {
        if (_listener != null) {
            _listener.onSubscribed();
        }
    }

    function emitTreadmillData(
        bytes as ByteArray,
        receivedAtMs as Number
    ) as Void {
        if (_listener != null) {
            _listener.onTreadmillData(bytes, receivedAtMs);
        }
    }

    function emitDisconnected(reason as String?) as Void {
        if (_listener != null) {
            _listener.onDisconnected(reason);
        }
    }
}
