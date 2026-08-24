import Toybox.Lang;
import Toybox.BluetoothLowEnergy;

class ReplayFtmsTransport {
    private var _listener as FtmsTransportListener?;
    private var _scanStarted as Boolean;
    private var _requestedIdentity as String?;
    private var _requestedScanResult as BluetoothLowEnergy.ScanResult?;
    private var _discoveryRequested as Boolean;
    private var _subscriptionRequested as Boolean;

    function initialize() {
        _listener = null;
        _scanStarted = false;
        _requestedIdentity = null;
        _requestedScanResult = null;
        _discoveryRequested = false;
        _subscriptionRequested = false;
    }

    function setListener(listener as FtmsTransportListener) as Void {
        _listener = listener;
    }

    function startScan() as Void {
        _scanStarted = true;
    }

    function discoverTreadmillData() as Void {
        _discoveryRequested = true;
    }

    function wasDiscoveryRequested() as Boolean {
        return _discoveryRequested;
    }

    function emitConnected() as Void {
        if (_listener != null) {
            _listener.onConnected();
        }
    }

    function stopScan() as Void {
        _scanStarted = false;
    }

    function connect(
        identity as String,
        scanResult as BluetoothLowEnergy.ScanResult?
    ) as Void {
        _requestedIdentity = identity;
        _requestedScanResult = scanResult;
    }

    function subscribeTreadmillData() as Void {
        _subscriptionRequested = true;
    }

    function wasSubscriptionRequested() as Boolean {
        return _subscriptionRequested;
    }

    function emitTreadmillDataDiscovered() as Void {
        if (_listener != null) {
            _listener.onTreadmillDataDiscovered();
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

    function disconnect() as Void {
    }

    function wasScanStarted() as Boolean {
        return _scanStarted;
    }

    function emitScanResult(
        identity as String,
        name as String?,
        rssi as Number
    ) as Void {
        if (_listener != null) {
            _listener.onScanResult(identity, name, rssi, null);
        }
    }

    function emitConnectionFailed(reason as String) as Void {
        if (_listener != null) {
            _listener.onConnectionFailed(reason);
        }
    }

    function emitSubscribed() as Void {
        if (_listener != null) {
            _listener.onSubscribed();
        }
    }

    function emitDisconnected(reason as String?) as Void {
        if (_listener != null) {
            _listener.onDisconnected(reason);
        }
    }

    function getRequestedIdentity() as String? {
        return _requestedIdentity;
    }

    function getRequestedScanResult() as BluetoothLowEnergy.ScanResult? {
        return _requestedScanResult;
    }
}
