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
            candidates[0].identity,
            "candidate identity"
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
    static function testSelectingCandidateConnectsOnlyToItsIdentity(
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
            transport.getRequestedIdentity(),
            "requested connection identity"
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
            transport.getRequestedIdentity() == null,
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
        scheduler.emit();
        transport.emitConnectionFailed("scan failed");
        Test.assertEqualMessage(2000, scheduler.getScheduledDelayMs(), "second retry");
        scheduler.emit();
        transport.emitConnectionFailed("scan failed");
        Test.assertEqualMessage(5000, scheduler.getScheduledDelayMs(), "third retry");
        scheduler.emit();
        transport.emitConnectionFailed("scan failed");
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
        var coordinator = new FtmsConnectionCoordinator(transport);

        coordinator.beginScan();
        transport.emitScanResult("treadmill-1", "FTMS-MOCK", -54);
        coordinator.selectCandidate("treadmill-1");
        transport.emitConnected();
        transport.emitTreadmillDataDiscovered();
        transport.emitTreadmillData([0x00, 0x00, 0x20, 0x03]b, 6000);

        transport.emitDisconnected("link lost");
        transport.emitDisconnected("still lost");
        Test.assertEqualMessage(1, coordinator.getLostAlertCount(), "lost edge alert");

        coordinator.beginScan();
        transport.emitScanResult("treadmill-1", "FTMS-MOCK", -54);
        coordinator.selectCandidate("treadmill-1");
        transport.emitConnected();
        transport.emitTreadmillDataDiscovered();
        transport.emitTreadmillData([0x00, 0x00, 0x20, 0x03]b, 7000);
        transport.emitTreadmillData([0x00, 0x00, 0x20, 0x03]b, 8000);

        Test.assertEqualMessage(1, coordinator.getRestoredAlertCount(), "restored edge alert");
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
}
