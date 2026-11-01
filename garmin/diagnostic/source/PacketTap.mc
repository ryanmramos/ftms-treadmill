import Toybox.Lang;
import Toybox.System;

// sits between the BLE transport and the coordinator. keeps the last raw
// notification and the recent transport events for the live screen, then
// forwards every event unchanged.
class PacketTap {
    var lastBytes as ByteArray?;
    var packetCount as Number;
    // newest first, each prefixed with watch uptime in seconds
    var events as Array<String>;
    private var _coordinator as FtmsConnectionCoordinator;

    function initialize(coordinator as FtmsConnectionCoordinator) {
        _coordinator = coordinator;
        lastBytes = null;
        packetCount = 0;
        events = [];
    }

    function onScanResult(device as Object, name as String?, rssi as Number) as Void {
        _coordinator.onScanResult(device, name, rssi);
    }

    function onConnected() as Void {
        record("connected");
        _coordinator.onConnected();
    }

    function onConnectionFailed(reason as String) as Void {
        record("failed: " + reason);
        _coordinator.onConnectionFailed(reason);
    }

    function onTreadmillDataDiscovered() as Void {
        record("treadmill data found");
        _coordinator.onTreadmillDataDiscovered();
    }

    function onSubscribed() as Void {
        record("subscribed");
        _coordinator.onSubscribed();
    }

    function onTreadmillData(bytes as ByteArray, receivedAtMs as Number) as Void {
        lastBytes = bytes;
        packetCount += 1;
        _coordinator.onTreadmillData(bytes, receivedAtMs);
    }

    function onDisconnected(reason as String?) as Void {
        record(reason != null ? "disconnected: " + reason : "disconnected");
        _coordinator.onDisconnected(reason);
    }

    private function record(event as String) as Void {
        events = [(System.getTimer() / 1000) + "s " + event].addAll(events) as Array<String>;

        if (events.size() > 3) {
            events = events.slice(0, 3);
        }
    }
}
