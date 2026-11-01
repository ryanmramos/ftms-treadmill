import Toybox.Lang;
import Toybox.Test;

class FtmsConnectionCoordinatorTest {
    (:test)
    static function testStartsUnconfigured(
        logger as Test.Logger
    ) as Boolean {
        var transport = new ReplayFtmsTransport();
        var coordinator = new FtmsConnectionCoordinator(transport);

        Test.assertEqualMessage(
            FtmsConnectionCoordinator.STATE_UNCONFIGURED,
            coordinator.getState(),
            "initial connection state"
        );

        return true;
    }

    (:test)
    static function testBeginScanCommandsTransport(
        logger as Test.Logger
    ) as Boolean {
        var transport = new ReplayFtmsTransport();
        var coordinator = new FtmsConnectionCoordinator(transport);

        coordinator.beginScan();

        Test.assertMessage(
            transport.wasScanStarted(),
            "beginScan should command the transport"
        );
        Test.assertEqualMessage(
            FtmsConnectionCoordinator.STATE_SCANNING,
            coordinator.getState(),
            "state after beginning scan"
        );

        return true;
    }

    (:test)
    static function testScanResultIsStoredWhileScanning(
        logger as Test.Logger
    ) as Boolean {
        var transport = new ReplayFtmsTransport();
        var coordinator = new FtmsConnectionCoordinator(transport);

        coordinator.beginScan();
        transport.emitScanResult("treadmill-1", "FTMS-MOCK", -54);

        var candidates = coordinator.getScanCandidates();

        Test.assertEqualMessage(1, candidates.size(), "candidate count");
        Test.assertEqualMessage(
            "treadmill-1",
            candidates[0].device,
            "candidate device"
        );
        Test.assertEqualMessage(
            "FTMS-MOCK",
            candidates[0].name,
            "candidate name"
        );
        Test.assertEqualMessage(-54, candidates[0].rssi, "candidate signal strength");

        return true;
    }

    (:test)
    static function testScanResultIsIgnoredOutsideScanning(
        logger as Test.Logger
    ) as Boolean {
        var transport = new ReplayFtmsTransport();
        var coordinator = new FtmsConnectionCoordinator(transport);

        transport.emitScanResult("treadmill-1", "FTMS-MOCK", -54);

        Test.assertEqualMessage(
            0,
            coordinator.getScanCandidates().size(),
            "candidates outside scanning"
        );

        return true;
    }

    (:test)
    static function testScanCandidateIsDeduplicated(
        logger as Test.Logger
    ) as Boolean {
        var transport = new ReplayFtmsTransport();
        var coordinator = new FtmsConnectionCoordinator(transport);

        coordinator.beginScan();
        transport.emitScanResult("treadmill-1", "FTMS-MOCK", -70);
        transport.emitScanResult("treadmill-1", "FTMS-MOCK", -48);

        var candidates = coordinator.getScanCandidates();

        Test.assertEqualMessage(1, candidates.size(), "deduplicated candidate count");
        Test.assertEqualMessage(-48, candidates[0].rssi, "refreshed signal strength");

        return true;
    }

    (:test)
    static function testSelectingCandidateConnectsOnlyToThatDevice(
        logger as Test.Logger
    ) as Boolean {
        var transport = new ReplayFtmsTransport();
        var coordinator = new FtmsConnectionCoordinator(transport);

        coordinator.beginScan();
        transport.emitScanResult("treadmill-1", "FTMS-MOCK", -54);

        Test.assertMessage(
            coordinator.selectCandidate("treadmill-1"),
            "known candidate should be selectable"
        );
        Test.assertEqualMessage(
            FtmsConnectionCoordinator.STATE_CONNECTING,
            coordinator.getState(),
            "state after selection"
        );
        Test.assertMessage(
            !transport.wasScanStarted(),
            "selection should stop scanning"
        );
        Test.assertEqualMessage(
            "treadmill-1",
            transport.getRequestedDevice(),
            "requested connection device"
        );

        return true;
    }

    (:test)
    static function testUnknownCandidateCannotBeSelected(
        logger as Test.Logger
    ) as Boolean {
        var transport = new ReplayFtmsTransport();
        var coordinator = new FtmsConnectionCoordinator(transport);

        coordinator.beginScan();

        Test.assertMessage(
            !coordinator.selectCandidate("unknown-treadmill"),
            "unknown candidate should be rejected"
        );
        Test.assertEqualMessage(
            FtmsConnectionCoordinator.STATE_SCANNING,
            coordinator.getState(),
            "state after rejected selection"
        );
        Test.assertMessage(
            transport.getRequestedDevice() == null,
            "rejected selection should not request connection"
        );

        return true;
    }

    (:test)
    static function testConnectedEventStartsDiscovery(
        logger as Test.Logger
    ) as Boolean {
        var transport = new ReplayFtmsTransport();
        var coordinator = new FtmsConnectionCoordinator(transport);

        coordinator.beginScan();
        transport.emitScanResult("treadmill-1", "FTMS-MOCK", -54);
        coordinator.selectCandidate("treadmill-1");

        transport.emitConnected();

        Test.assertEqualMessage(
            FtmsConnectionCoordinator.STATE_DISCOVERING,
            coordinator.getState(),
            "state after connected event"
        );
        Test.assertMessage(
            transport.wasDiscoveryRequested(),
            "connected event should request discovery"
        );

        return true;
    }

    (:test)
    static function testDiscoverySuccessStartsSubscription(
        logger as Test.Logger
    ) as Boolean {
        var transport = new ReplayFtmsTransport();
        var coordinator = new FtmsConnectionCoordinator(transport);

        coordinator.beginScan();
        transport.emitScanResult("treadmill-1", "FTMS-MOCK", -54);
        coordinator.selectCandidate("treadmill-1");
        transport.emitConnected();

        transport.emitTreadmillDataDiscovered();

        Test.assertEqualMessage(
            FtmsConnectionCoordinator.STATE_SUBSCRIBING,
            coordinator.getState(),
            "state after discovery"
        );
        Test.assertMessage(
            transport.wasSubscriptionRequested(),
            "discovery should request subscription"
        );

        return true;
    }

    (:test)
    static function testValidTreadmillDataMakesCoordinatorReady(
        logger as Test.Logger
    ) as Boolean {
        var transport = new ReplayFtmsTransport();
        var coordinator = new FtmsConnectionCoordinator(transport);

        coordinator.beginScan();
        transport.emitScanResult("treadmill-1", "FTMS-MOCK", -54);
        coordinator.selectCandidate("treadmill-1");
        transport.emitConnected();
        transport.emitTreadmillDataDiscovered();

        // Flags are zero; instantaneous speed is present: 800 = 8.00 km/h
        transport.emitTreadmillData([0x00, 0x00, 0x20, 0x03]b, 1111);

        Test.assertEqualMessage(
            FtmsConnectionCoordinator.STATE_READY,
            coordinator.getState(),
            "state after valid treadmill data"
        );
        Test.assertMessage(
            coordinator.getLatestSample() != null,
            "latest sample should be available"
        );

        return true;
    }

    (:test)
    static function testFragmentedTreadmillDataMakesCoordinatorReady(
        logger as Test.Logger
    ) as Boolean {
        var transport = new ReplayFtmsTransport();
        var coordinator = new FtmsConnectionCoordinator(transport);

        coordinator.beginScan();
        transport.emitScanResult("treadmill-1", "FTMS-MOCK", -54);
        coordinator.selectCandidate("treadmill-1");
        transport.emitConnected();
        transport.emitTreadmillDataDiscovered();

        transport.emitTreadmillData([0x01, 0x00]b, 1000);
        transport.emitTreadmillData([0x00, 0x00, 0x20, 0x03]b, 1001);

        Test.assertEqualMessage(
            FtmsConnectionCoordinator.STATE_READY,
            coordinator.getState(),
            "state after treadmill data"
        );
        Test.assertMessage(
            coordinator.getLatestSample() != null,
            "latest sample should be available"
        );

        return true;
    }

    (:test)
    static function testMalformedDataDoesNotMakeCoordinatorReady(
        logger as Test.Logger
    ) as Boolean {
        var transport = new ReplayFtmsTransport();
        var coordinator = new FtmsConnectionCoordinator(transport);

        coordinator.beginScan();
        transport.emitScanResult("treadmill-1", "FTMS-MOCK", -54);
        coordinator.selectCandidate("treadmill-1");
        transport.emitConnected();
        transport.emitTreadmillDataDiscovered();

        // Flags require speed, but only one speed byte follows.
        transport.emitTreadmillData([0x00, 0x00, 0x20]b, 2222);

        Test.assertEqualMessage(
            FtmsConnectionCoordinator.STATE_SUBSCRIBING,
            coordinator.getState(),
            "state after malformed treadmill data"
        );
        Test.assertMessage(
            coordinator.getLatestSample() != null,
            "malformed sample should be retained for diagnostics"
        );

        return true;
    }

    (:test)
    static function testWarningsDoNotBlockValidSpeed(
        logger as Test.Logger
    ) as Boolean {
        var transport = new ReplayFtmsTransport();
        var coordinator = new FtmsConnectionCoordinator(transport);

        coordinator.beginScan();
        transport.emitScanResult("treadmill-1", "FTMS-MOCK", -54);
        coordinator.selectCandidate("treadmill-1");
        transport.emitConnected();
        transport.emitTreadmillDataDiscovered();

        // Incline is unavailable, but speed is a valid zero sample.
        transport.emitTreadmillData([
            0x08, 0x00,
            0x00, 0x00,
            0xFF, 0x7F,
            0x00, 0x00
        ]b, 3333);

        Test.assertEqualMessage(
            FtmsConnectionCoordinator.STATE_READY,
            coordinator.getState(),
            "warning-bearing sample should be ready"
        );
        var sample = coordinator.getLatestSample();
        Test.assertMessage(sample != null, "warning-bearing sample is retained");
        if (sample == null) {
            return false;
        }
        Test.assertEqualMessage(
            1,
            sample.parseWarnings.size(),
            "warning should remain diagnostic metadata"
        );

        return true;
    }

    (:test)
    static function testRetryScheduleIsExactAndBacksOff(
        logger as Test.Logger
    ) as Boolean {
        var transport = new ReplayFtmsTransport();
        var scheduler = new ReplayFtmsScheduler();
        var coordinator = new FtmsConnectionCoordinator(transport);
        coordinator.setScheduler(scheduler);

        coordinator.beginScan();
        transport.emitScanResult("treadmill-1", "FTMS-MOCK", -54);
        coordinator.selectCandidate("treadmill-1");

        transport.emitDisconnected("link lost");
        Test.assertEqualMessage(1000, scheduler.getScheduledDelayMs(), "first retry");
        failReconnect(transport, scheduler);
        Test.assertEqualMessage(2000, scheduler.getScheduledDelayMs(), "second retry");
        failReconnect(transport, scheduler);
        Test.assertEqualMessage(5000, scheduler.getScheduledDelayMs(), "third retry");
        failReconnect(transport, scheduler);
        Test.assertEqualMessage(10000, scheduler.getScheduledDelayMs(), "steady retry");

        return true;
    }

    (:test)
    static function testStaleThresholdIsThreeSeconds(
        logger as Test.Logger
    ) as Boolean {
        var transport = new ReplayFtmsTransport();
        var coordinator = new FtmsConnectionCoordinator(transport);

        coordinator.beginScan();
        transport.emitScanResult("treadmill-1", "FTMS-MOCK", -54);
        coordinator.selectCandidate("treadmill-1");
        transport.emitConnected();
        transport.emitTreadmillDataDiscovered();
        transport.emitTreadmillData([0x00, 0x00, 0x20, 0x03]b, 5000);

        coordinator.onTimerTick(7999);
        Test.assertEqualMessage(
            FtmsConnectionCoordinator.STATE_READY,
            coordinator.getState(),
            "sample before stale threshold"
        );
        coordinator.onTimerTick(8000);
        Test.assertEqualMessage(
            FtmsConnectionCoordinator.STATE_STALE,
            coordinator.getState(),
            "sample at stale threshold"
        );

        return true;
    }

    (:test)
    static function testDisconnectAlertsOnceAndReconnectAlertsOnce(
        logger as Test.Logger
    ) as Boolean {
        var transport = new ReplayFtmsTransport();
        var scheduler = new ReplayFtmsScheduler();
        var listener = new RecordingCoordinatorListener();
        var coordinator = new FtmsConnectionCoordinator(transport);
        coordinator.setScheduler(scheduler);
        coordinator.setListener(listener);

        subscribe(transport, coordinator, "treadmill-1");
        transport.emitTreadmillData([0x00, 0x00, 0x20, 0x03]b, 6000);

        transport.emitDisconnected("link lost");
        transport.emitDisconnected("still lost");
        Test.assertEqualMessage(1, listener.lostCount, "lost edge alert");

        // reconnect happens on its own once the saved treadmill is seen again
        scheduler.emit();
        transport.emitScanResult("treadmill-1", "FTMS-MOCK", -54);
        transport.emitConnected();
        transport.emitTreadmillDataDiscovered();
        transport.emitTreadmillData([0x00, 0x00, 0x20, 0x03]b, 7000);
        transport.emitTreadmillData([0x00, 0x00, 0x20, 0x03]b, 8000);

        Test.assertEqualMessage(1, listener.restoredCount, "restored edge alert");
        Test.assertEqualMessage(
            FtmsConnectionCoordinator.STATE_READY,
            coordinator.getState(),
            "ready after reconnect"
        );
        return true;
    }

    (:test)
    static function testReconnectPicksSavedTreadmillOnly(
        logger as Test.Logger
    ) as Boolean {
        var transport = new ReplayFtmsTransport();
        var scheduler = new ReplayFtmsScheduler();
        var coordinator = new FtmsConnectionCoordinator(transport);
        coordinator.setScheduler(scheduler);

        subscribe(transport, coordinator, "treadmill-1");
        transport.emitTreadmillData([0x00, 0x00, 0x20, 0x03]b, 1000);
        transport.emitDisconnected("link lost");
        scheduler.emit();

        transport.emitScanResult("treadmill-2", "FTMS-MOCK", -40);
        Test.assertEqualMessage(
            FtmsConnectionCoordinator.STATE_SCANNING,
            coordinator.getState(),
            "another FTMS device is ignored"
        );
        Test.assertEqualMessage(1, transport.getConnectCount(), "no connect to the other device");

        transport.emitScanResult("treadmill-1", "FTMS-MOCK", -60);
        Test.assertEqualMessage(
            FtmsConnectionCoordinator.STATE_CONNECTING,
            coordinator.getState(),
            "saved treadmill reconnects"
        );
        Test.assertEqualMessage("treadmill-1", transport.getRequestedDevice(), "reconnect target");
        return true;
    }

    (:test)
    static function testPickerScanDoesNotAutoConnect(
        logger as Test.Logger
    ) as Boolean {
        var transport = new ReplayFtmsTransport();
        var coordinator = new FtmsConnectionCoordinator(transport);

        subscribe(transport, coordinator, "treadmill-1");
        coordinator.stop();
        coordinator.beginScan();
        transport.emitScanResult("treadmill-1", "FTMS-MOCK", -54);

        Test.assertEqualMessage(
            FtmsConnectionCoordinator.STATE_SCANNING,
            coordinator.getState(),
            "the picker waits for a choice"
        );
        return true;
    }

    (:test)
    static function testSubscribedButSilentGoesStale(
        logger as Test.Logger
    ) as Boolean {
        var transport = new ReplayFtmsTransport();
        var coordinator = new FtmsConnectionCoordinator(transport);

        subscribe(transport, coordinator, "treadmill-1");
        transport.emitSubscribed();

        coordinator.onTimerTick(1000);
        coordinator.onTimerTick(3999);
        Test.assertEqualMessage(
            FtmsConnectionCoordinator.STATE_SUBSCRIBING,
            coordinator.getState(),
            "before stale threshold"
        );
        coordinator.onTimerTick(4000);
        Test.assertEqualMessage(
            FtmsConnectionCoordinator.STATE_STALE,
            coordinator.getState(),
            "no data for three seconds after subscribing"
        );
        return true;
    }

    (:test)
    static function testFailedDiscoveryDisconnects(
        logger as Test.Logger
    ) as Boolean {
        var transport = new ReplayFtmsTransport();
        var scheduler = new ReplayFtmsScheduler();
        var coordinator = new FtmsConnectionCoordinator(transport);
        coordinator.setScheduler(scheduler);

        coordinator.beginScan();
        transport.emitScanResult("treadmill-1", "FTMS-MOCK", -54);
        coordinator.selectCandidate("treadmill-1");
        transport.emitConnected();
        transport.emitConnectionFailed("ftms service not found");

        Test.assertEqualMessage(1, transport.getDisconnectCount(), "half-open link dropped");
        Test.assertEqualMessage(
            FtmsConnectionCoordinator.STATE_BACKOFF,
            coordinator.getState(),
            "backoff after failure"
        );

        // the disconnect echo must not count as a second failure
        transport.emitDisconnected("unpaired");
        Test.assertEqualMessage(2000, coordinator.retryDelayMsForCurrentAttempt(), "one attempt used");
        return true;
    }

    (:test)
    static function testFailedFirstConnectDoesNotAlertLost(
        logger as Test.Logger
    ) as Boolean {
        var transport = new ReplayFtmsTransport();
        var listener = new RecordingCoordinatorListener();
        var coordinator = new FtmsConnectionCoordinator(transport);
        coordinator.setListener(listener);

        subscribe(transport, coordinator, "treadmill-1");
        transport.emitDisconnected("link lost");

        Test.assertEqualMessage(0, listener.lostCount, "never live, so nothing was lost");
        return true;
    }

    (:test)
    static function testStopIgnoresDisconnectEcho(
        logger as Test.Logger
    ) as Boolean {
        var transport = new ReplayFtmsTransport();
        var scheduler = new ReplayFtmsScheduler();
        var coordinator = new FtmsConnectionCoordinator(transport);
        coordinator.setScheduler(scheduler);

        subscribe(transport, coordinator, "treadmill-1");
        transport.emitTreadmillData([0x00, 0x00, 0x20, 0x03]b, 1000);
        coordinator.stop();
        transport.emitDisconnected("unpaired");

        Test.assertEqualMessage(
            FtmsConnectionCoordinator.STATE_UNCONFIGURED,
            coordinator.getState(),
            "stays stopped"
        );
        Test.assertMessage(scheduler.getScheduledDelayMs() == null, "no retry after stop");
        return true;
    }

    (:test)
    static function testStateChangesReachListener(
        logger as Test.Logger
    ) as Boolean {
        var transport = new ReplayFtmsTransport();
        var listener = new RecordingCoordinatorListener();
        var coordinator = new FtmsConnectionCoordinator(transport);
        coordinator.setListener(listener);

        subscribe(transport, coordinator, "treadmill-1");
        transport.emitTreadmillData([0x00, 0x00, 0x20, 0x03]b, 1000);
        transport.emitTreadmillData([0x00, 0x00, 0x20, 0x03]b, 2000);

        var expected = [
            FtmsConnectionCoordinator.STATE_SCANNING,
            FtmsConnectionCoordinator.STATE_CONNECTING,
            FtmsConnectionCoordinator.STATE_DISCOVERING,
            FtmsConnectionCoordinator.STATE_SUBSCRIBING,
            FtmsConnectionCoordinator.STATE_READY
        ];
        Test.assertEqualMessage(expected.size(), listener.states.size(), "one event per change");
        for (var i = 0; i < expected.size(); i += 1) {
            Test.assertEqualMessage(expected[i], listener.states[i], "state " + i);
        }
        return true;
    }

    (:test)
    static function testStopCancelsScheduledWork(
        logger as Test.Logger
    ) as Boolean {
        var transport = new ReplayFtmsTransport();
        var scheduler = new ReplayFtmsScheduler();
        var coordinator = new FtmsConnectionCoordinator(transport);
        coordinator.setScheduler(scheduler);

        coordinator.beginScan();
        transport.emitScanResult("treadmill-1", "FTMS-MOCK", -54);
        coordinator.selectCandidate("treadmill-1");
        transport.emitDisconnected("link lost");
        coordinator.stop();

        Test.assertMessage(scheduler.getScheduledDelayMs() == null, "stop cancels retry");
        Test.assertEqualMessage(
            FtmsConnectionCoordinator.STATE_UNCONFIGURED,
            coordinator.getState(),
            "state after stop"
        );
        return true;
    }

    // scan, pick, connect, and discover, leaving the coordinator in SUBSCRIBING
    static function subscribe(
        transport as ReplayFtmsTransport,
        coordinator as FtmsConnectionCoordinator,
        device as String
    ) as Void {
        coordinator.beginScan();
        transport.emitScanResult(device, "FTMS-MOCK", -54);
        coordinator.selectCandidate(device);
        transport.emitConnected();
        transport.emitTreadmillDataDiscovered();
    }

    // fire the pending retry, see the saved treadmill, and fail to connect
    static function failReconnect(
        transport as ReplayFtmsTransport,
        scheduler as ReplayFtmsScheduler
    ) as Void {
        scheduler.emit();
        transport.emitScanResult("treadmill-1", "FTMS-MOCK", -54);
        transport.emitConnectionFailed("pairing failed");
    }
}
