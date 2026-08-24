import Toybox.Lang;
import Toybox.BluetoothLowEnergy;

typedef FtmsTransportListener as interface {
    function onScanResult(
        identity as String,
        name as String?,
        rssi as Number,
        scanResult as BluetoothLowEnergy.ScanResult?
    ) as Void;

    function onConnected() as Void;
    function onConnectionFailed(reason as String) as Void;
    function onSubscribed() as Void;

    function onTreadmillDataDiscovered() as Void;
    function onTreadmillData(
        bytes as ByteArray,
        receivedAtMs as Number
    ) as Void;

    function onDisconnected(reason as String?) as Void;
};

typedef FtmsTransport as interface {
    function setListener(listener as FtmsTransportListener) as Void;
    function startScan() as Void;
    function stopScan() as Void;
    function connect(
        identity as String,
        scanResult as BluetoothLowEnergy.ScanResult?
    ) as Void;
    function discoverTreadmillData() as Void;
    function subscribeTreadmillData() as Void;
    function disconnect() as Void;
};
