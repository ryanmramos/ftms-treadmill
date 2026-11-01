import Toybox.Lang;
import Toybox.BluetoothLowEnergy;

// Production BLE transport. Owns the BleDelegate, FTMS profile registration,
// FTMS scan filtering, pairing, the treadmill data CCCD subscription, and
// read-only notification forwarding. It never writes treadmill control
// characteristics.
class FtmsBleTransport extends BluetoothLowEnergy.BleDelegate {
    private var _listener as FtmsTransportListener?;
    private var _device as BluetoothLowEnergy.Device?;
    private var _treadmillDataCharacteristic as BluetoothLowEnergy.Characteristic?;

    private var _profileRegistered as Boolean;
    private var _profileFailed as Boolean;
    private var _discoveryPending as Boolean;

    function initialize() {
        BleDelegate.initialize();
        _listener = null;
        _device = null;
        _treadmillDataCharacteristic = null;
        _profileRegistered = false;
        _profileFailed = false;
        _discoveryPending = false;
        BluetoothLowEnergy.setDelegate(self);
        unpairAll();
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
                // the ScanResult itself is the device handle
                _listener.onScanResult(
                    scanResult, scanResult.getDeviceName(), scanResult.getRssi()
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
            // free the pairing slot pairDevice claimed
            BluetoothLowEnergy.unpairDevice(device);
            _device = null;

            if (_listener != null) {
                _listener.onConnectionFailed("connection rejected");
            }

            return;
        }

        if (state == BluetoothLowEnergy.CONNECTION_STATE_DISCONNECTED) {
            // free the pairing slot. a paired device that stays registered
            // makes the next pairDevice for it fail.
            BluetoothLowEnergy.unpairDevice(device);
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

    function connect(device as Object) as Void {
        var reason = "pairing failed";

        try {
            _device = BluetoothLowEnergy.pairDevice(
                device as BluetoothLowEnergy.ScanResult
            );
        } catch (ex instanceof BluetoothLowEnergy.DevicePairException) {
            _device = null;
            var message = ex.getErrorMessage();

            if (message != null) {
                reason += ": " + message;
            }
        }

        if (_device == null && _listener != null) {
            _listener.onConnectionFailed(reason);
        }
    }

    function isSameDevice(a as Object, b as Object) as Boolean {
        return (a as BluetoothLowEnergy.ScanResult).isSameDevice(
            b as BluetoothLowEnergy.ScanResult
        );
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
        if (_profileFailed) {
            if (_listener != null) {
                _listener.onConnectionFailed("ftms profile registration failed");
            }
            return;
        }

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
            _profileFailed = true;
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

    // this app holds at most one pairing. clear any left over from a crash or
    // an earlier build so a fresh pairDevice always has a slot.
    private function unpairAll() as Void {
        var devices = [] as Array<BluetoothLowEnergy.Device>;
        var paired = BluetoothLowEnergy.getPairedDevices();
        var next = paired.next();

        while (next != null) {
            devices.add(next as BluetoothLowEnergy.Device);
            next = paired.next();
        }

        for (var i = 0; i < devices.size(); i += 1) {
            BluetoothLowEnergy.unpairDevice(devices[i]);
        }
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

        try {
            BluetoothLowEnergy.registerProfile(profile);
        } catch (ex instanceof BluetoothLowEnergy.ProfileRegistrationException) {
            _profileFailed = true;
        }
    }
}
