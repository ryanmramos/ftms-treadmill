import Toybox.Lang;
import Toybox.BluetoothLowEnergy;

// Production BLE transport shell. Connection and characteristic callbacks are
// added in later steps.
class FtmsBleTransport extends BluetoothLowEnergy.BleDelegate {
    private var _listener as FtmsTransportListener?;
    private var _knownScanResults as Array<BluetoothLowEnergy.ScanResult>;
    private var _device as BluetoothLowEnergy.Device?;
    private var _treadmillDataCharacteristic as BluetoothLowEnergy.Characteristic?;

    private var _profileRegistered as Boolean;
    private var _discoveryPending as Boolean;

    function initialize() {
        BleDelegate.initialize();
        _listener = null;
        _knownScanResults = [];
        _device = null;
        _treadmillDataCharacteristic = null;
        _profileRegistered = false;
        _discoveryPending = false;
        BluetoothLowEnergy.setDelegate(self);
        registerFtmsProfile();
    }

    function setListener(listener as FtmsTransportListener) as Void {
        _listener = listener;
    }

    function onScanResults(scanResults as BluetoothLowEnergy.Iterator) as Void {
        var nextResult = scanResults.next();
        while (nextResult != null) {
            var scanResult = nextResult as BluetoothLowEnergy.ScanResult;

            if (advertisesFtmsService(scanResult) && _listener != null) {
                _listener.onScanResult(
                    identityFor(scanResult), scanResult.getDeviceName(),
                    scanResult.getRssi(), scanResult
                );
            }

            nextResult = scanResults.next();
        }
    }

    function onConnectedStateChanged(
        device as BluetoothLowEnergy.Device,
        state as BluetoothLowEnergy.ConnectionState
    ) as Void {
        if (state == BluetoothLowEnergy.CONNECTION_STATE_CONNECTED) {
            _device = device;

            if (_listener != null) {
                _listener.onConnected();
            }

            return;
        }

        if (state == BluetoothLowEnergy.CONNECTION_STATE_REJECTED) {
            _device = null;

            if (_listener != null) {
                _listener.onConnectionFailed("connection rejected");
            }
        }
    }

    function startScan() as Void {
        BluetoothLowEnergy.setScanState(
            BluetoothLowEnergy.SCAN_STATE_SCANNING
        );
    }

    function stopScan() as Void {
        BluetoothLowEnergy.setScanState(
            BluetoothLowEnergy.SCAN_STATE_OFF
        );
    }

    function connect(
        identity as String,
        scanResult as BluetoothLowEnergy.ScanResult?
    ) as Void {
        if (scanResult == null) {
            if (_listener != null) {
                _listener.onConnectionFailed("missing scan result");
            }
            return;
        }

        _device = BluetoothLowEnergy.pairDevice(scanResult);

        if (_device == null && _listener != null) {
            _listener.onConnectionFailed("pairing failed");
        }
    }

    function discoverTreadmillData() as Void {
        if (!_profileRegistered) {
            _discoveryPending = true;
            return;
        }

        discoverTreadmillDataNow();
    }

    function discoverTreadmillDataNow() as Void {
        var device = _device;

        if (_device == null) {
            if (_listener != null) {
                _listener.onConnectionFailed("no connected device");
            }
            return;
        }

        var service = device.getService(BluetoothLowEnergy.stringToUuid(FtmsConstants.FTMS_SERVICE_UUID));

        if (service == null) {
            if (_listener != null) {
                _listener.onConnectionFailed("ftms service not found");
            }
            return;
        }

        _treadmillDataCharacteristic = service.getCharacteristic(
            BluetoothLowEnergy.stringToUuid(FtmsConstants.TREADMILL_DATA_UUID)
        );

        if (_treadmillDataCharacteristic == null) {
            if (_listener != null) {
                _listener.onConnectionFailed("treadmill data characteristic not found");
            }
            return;
        }

        if (_listener != null) {
            _listener.onTreadmillDataDiscovered();
        }
    }

    function onProfileRegister(
        uuid as BluetoothLowEnergy.Uuid,
        status as BluetoothLowEnergy.Status
    ) as Void {
        if (!uuid.equals(BluetoothLowEnergy.stringToUuid(FtmsConstants.FTMS_SERVICE_UUID))) {
            return;
        }

        if (status != BluetoothLowEnergy.STATUS_SUCCESS) {
            _profileRegistered = false;
            _discoveryPending = false;

            if (_listener != null) {
                _listener.onConnectionFailed("ftms profile registration failed");
            }

            return;
        }

        _profileRegistered = true;

        if (_discoveryPending) {
            _discoveryPending = false;
            discoverTreadmillDataNow();
        }
    }

    private function advertisesFtmsService(
        scanResult as BluetoothLowEnergy.ScanResult
    ) as Boolean {
        var serviceUuids = scanResult.getServiceUuids();
        var nextUuid = serviceUuids.next();

        while (nextUuid != null) {
            var serviceUuid = nextUuid as BluetoothLowEnergy.Uuid;

            if (serviceUuid.equals(FtmsConstants.FTMS_SERVICE_UUID)) {
                return true;
            }

            nextUuid = serviceUuids.next();
        }

        return false;
    }

    private function identityFor(
        scanResult as BluetoothLowEnergy.ScanResult
    ) as String {
        for (var i = 0; i < _knownScanResults.size(); i += 1) {
            if (_knownScanResults[i].isSameDevice(scanResult)) {
                return "ble-" + i;
            }
        }

        _knownScanResults.add(scanResult);
        return "ble-" + (_knownScanResults.size() - 1);
    }

    private function registerFtmsProfile() as Void {
        var profile = {
            :uuid => BluetoothLowEnergy.stringToUuid(
                FtmsConstants.FTMS_SERVICE_UUID
            ),
            :characteristics => [{
                :uuid => BluetoothLowEnergy.stringToUuid(
                    FtmsConstants.TREADMILL_DATA_UUID
                ),
                :descriptors => [
                    BluetoothLowEnergy.cccdUuid()
                ]
            }]
        };

        BluetoothLowEnergy.registerProfile(profile);
    }
}
