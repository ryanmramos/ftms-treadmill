import Toybox.Lang;
import Toybox.BluetoothLowEnergy;

class FtmsScanCandidate {
    var identity as String;
    var name as String?;
    var rssi as Number;
    // The string is retained for simulator fixtures and diagnostics only.
    // Production selection must use this ScanResult with isSameDevice().
    var scanResult as BluetoothLowEnergy.ScanResult?;

    function initialize(
        identity as String,
        name as String?,
        rssi as Number,
        scanResult as BluetoothLowEnergy.ScanResult?
    ) {
        self.identity = identity;
        self.name = name;
        self.rssi = rssi;
        self.scanResult = scanResult;
    }
}
