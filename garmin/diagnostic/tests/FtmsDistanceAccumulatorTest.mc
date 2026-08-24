import Toybox.Lang;
import Toybox.Test;

class FtmsDistanceAccumulatorTest {
    (:test)
    static function testPausePreservesDistanceAndResumeRebaselines(
        logger as Test.Logger
    ) as Boolean {
        var accumulator = new FtmsDistanceAccumulator();
        accumulator.start(100.0);
        accumulator.observe(110.0);
        accumulator.pause();
        accumulator.observe(150.0);
        accumulator.resume(150.0);
        accumulator.observe(155.0);

        Test.assertEqualMessage(15.0, accumulator.getAccumulatedM(), "pause distance");
        return true;
    }

    (:test)
    static function testDisconnectPreservesDistanceWithoutBridgingGap(
        logger as Test.Logger
    ) as Boolean {
        var accumulator = new FtmsDistanceAccumulator();
        accumulator.start(100.0);
        accumulator.observe(110.0);
        accumulator.disconnect();
        accumulator.start(200.0);
        accumulator.observe(205.0);

        Test.assertEqualMessage(15.0, accumulator.getAccumulatedM(), "reconnect distance");
        return true;
    }

    (:test)
    static function testCounterResetStartsNewSegment(
        logger as Test.Logger
    ) as Boolean {
        var accumulator = new FtmsDistanceAccumulator();
        accumulator.start(100.0);
        accumulator.observe(110.0);
        accumulator.observe(5.0);
        accumulator.observe(8.0);

        Test.assertEqualMessage(13.0, accumulator.getAccumulatedM(), "counter reset distance");
        return true;
    }

    (:test)
    static function testMissingDistanceDoesNotBecomeZero(
        logger as Test.Logger
    ) as Boolean {
        var accumulator = new FtmsDistanceAccumulator();
        accumulator.start(100.0);
        accumulator.observe(110.0);
        accumulator.observe(null);

        Test.assertEqualMessage(10.0, accumulator.getAccumulatedM(), "missing distance");
        return true;
    }
}
