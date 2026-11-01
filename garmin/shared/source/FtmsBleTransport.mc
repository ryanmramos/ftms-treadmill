import Toybox.Lang;
import Toybox.BluetoothLowEnergy;

// Production BLE transport. Owns the BleDelegate, FTMS profile registration,
// FTMS scan filtering, pairing, the treadmill data CCCD subscription, and
// read-only notification forwarding. It never writes treadmill control
// characteristics.
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

            return;
        }

        if (state == BluetoothLowEnergy.CONNECTION_STATE_DISCONNECTED) {
            _device = null;
            _treadmillDataCharacteristic = null;

            if (_listener != null) {
                _listener.onDisconnected("disconnected");
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

    function disconnect() as Void {
        var device = _device;

        if (device != null) {
            BluetoothLowEnergy.unpairDevice(device);
        }

        _device = null;
        _treadmillDataCharacteristic = null;
        _discoveryPending = false;
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

    // writes 0x0001 to the treadmill data CCCD. this is the only write the
    // transport performs; it enables notifications and never sends control data.
    function subscribeTreadmillData() as Void {
        var characteristic = _treadmillDataCharacteristic;

        if (characteristic == null) {
            if (_listener != null) {
                _listener.onConnectionFailed("treadmill data characteristic missing");
            }
            return;
        }

        var cccd = characteristic.getDescriptor(BluetoothLowEnergy.cccdUuid());

        if (cccd == null) {
            if (_listener != null) {
                _listener.onConnectionFailed("cccd descriptor missing");
            }
            return;
        }

        try {
            cccd.requestWrite([0x01, 0x00]b);
        } catch (ex instanceof BluetoothLowEnergy.InvalidRequestException) {
            if (_listener != null) {
                _listener.onConnectionFailed("subscription failed");
            }
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

    function onDescriptorWrite(
        descriptor as BluetoothLowEnergy.Descriptor,
        status as BluetoothLowEnergy.Status
    ) as Void {
        var characteristic = descriptor.getCharacteristic();

        if (!characteristic.getUuid().equals(BluetoothLowEnergy.stringToUuid(FtmsConstants.TREADMILL_DATA_UUID))) {
            return;
        }

        if (status != BluetoothLowEnergy.STATUS_SUCCESS) {
            if (_listener != null) {
                _listener.onConnectionFailed("subscription failed");
            }
            return;
        }

        if (_listener != null) {
            _listener.onSubscribed();
        }
    }

    function onCharacteristicChanged(
        characteristic as BluetoothLowEnergy.Characteristic,
        value as ByteArray
    ) as Void {
        if (!characteristic.getUuid().equals(BluetoothLowEnergy.stringToUuid(FtmsConstants.TREADMILL_DATA_UUID))) {
            return;
        }

        if (_listener != null) {
            _listener.onTreadmillData(value, System.getTimer());
        }
    }

    private function advertisesFtmsService(
        scanResult as BluetoothLowEnergy.ScanResult
    ) as Boolean {
        var ftmsServiceUuid = BluetoothLowEnergy.stringToUuid(FtmsConstants.FTMS_SERVICE_UUID);
        var serviceUuids = scanResult.getServiceUuids();
        var nextUuid = serviceUuids.next();

        while (nextUuid != null) {
            var serviceUuid = nextUuid as BluetoothLowEnergy.Uuid;

            if (serviceUuid.equals(ftmsServiceUuid)) {
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
