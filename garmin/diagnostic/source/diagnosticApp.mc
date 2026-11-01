import Toybox.Application;
import Toybox.BluetoothLowEnergy;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// FTMS diagnostic watch app. picks a treadmill, shows live state and raw
// packets, and remembers the pick so the next launch reconnects on its own.
class diagnosticApp extends Application.AppBase {
    private const SAVED_DEVICE_KEY = "device";

    var coordinator as FtmsConnectionCoordinator;
    var tap as PacketTap;
    // what happened when saving or loading the picked device
    var storageStatus as String;
    private var _ticker as Timer.Timer;

    function initialize() {
        AppBase.initialize();
        var transport = new FtmsBleTransport();
        coordinator = new FtmsConnectionCoordinator(transport);
        coordinator.setScheduler(new FtmsTimerScheduler());
        // replaces the coordinator as the transport listener; the tap forwards to it
        tap = new PacketTap(coordinator);
        transport.setListener(tap);
        storageStatus = "";
        _ticker = new Timer.Timer();
    }

    function onStart(state as Dictionary?) as Void {
        var saved = Application.Storage.getValue(SAVED_DEVICE_KEY);

        if (saved instanceof BluetoothLowEnergy.ScanResult) {
            storageStatus = "saved device loaded";
            coordinator.reconnectTo(saved as BluetoothLowEnergy.ScanResult);
        } else {
            storageStatus = saved == null ? "no saved device" : "saved value unreadable";
            coordinator.beginScan();
        }

        _ticker.start(method(:onTick), 1000, true);
    }

    function onStop(state as Dictionary?) as Void {
        _ticker.stop();
        coordinator.stop();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new diagnosticView(), new diagnosticDelegate()];
    }

    // public so method(:onTick) can reference it
    function onTick() as Void {
        coordinator.onTimerTick(System.getTimer());
        WatchUi.requestUpdate();
    }

    // connects to a picked candidate and tries to save it for the next launch.
    // whether storage accepts a ScanResult is one of the things this app checks.
    function select(device as Object) as Void {
        if (!coordinator.selectCandidate(device)) {
            return;
        }

        try {
            Application.Storage.setValue(
                SAVED_DEVICE_KEY, device as Application.PropertyValueType
            );
            storageStatus = "device saved";
        } catch (ex instanceof Lang.Exception) {
            var message = ex.getErrorMessage();
            storageStatus = message != null ? "save failed: " + message : "save failed";
        }
    }

    // drops the link and the saved device, then scans for a new pick
    function forget() as Void {
        coordinator.stop();
        Application.Storage.deleteValue(SAVED_DEVICE_KEY);
        storageStatus = "saved device cleared";
        coordinator.beginScan();
    }
}

function getApp() as diagnosticApp {
    return Application.getApp() as diagnosticApp;
}
