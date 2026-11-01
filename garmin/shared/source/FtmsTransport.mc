import Toybox.Lang;

// device handles are opaque outside the transport that issued them. the BLE
// transport hands out BluetoothLowEnergy.ScanResult, replay transports use
// strings. only isSameDevice may compare two handles.

typedef FtmsTransportListener as interface {
    function onScanResult(
        device as Object,
        name as String?,
        rssi as Number
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
    function connect(device as Object) as Void;
    function isSameDevice(a as Object, b as Object) as Boolean;
    function discoverTreadmillData() as Void;
    function subscribeTreadmillData() as Void;
    function disconnect() as Void;
};
