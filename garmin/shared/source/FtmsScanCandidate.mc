import Toybox.Lang;

// one FTMS treadmill seen while scanning. device is the transport's opaque
// handle; compare handles only with FtmsTransport.isSameDevice, never by name.
class FtmsScanCandidate {
    var device as Object;
    var name as String?;
    var rssi as Number;

    function initialize(
        device as Object,
        name as String?,
        rssi as Number
    ) {
        self.device = device;
        self.name = name;
        self.rssi = rssi;
    }
}
