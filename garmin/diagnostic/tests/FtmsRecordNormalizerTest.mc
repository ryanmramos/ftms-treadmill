import Toybox.Lang;
import Toybox.Test;

class FtmsRecordNormalizerTest {
    (:test)
    static function testFlagsOnlyEarlierFragmentUsesFinalBytes(
        logger as Test.Logger
    ) as Boolean {
        var record = new FtmsLogicalRecord([
            [0x01, 0x00]b,
            [0x00, 0x00, 0x20, 0x03]b
        ], 0, 1001);

        var normalizer = new FtmsRecordNormalizer();
        var normalized = normalizer.normalize(record);

        Test.assertMessage(
            normalized != null,
            "flags-only earlier fragment should normalize"
        );

        if (normalized == null) {
            return false;
        }

        Test.assertEqualMessage(4, normalized.size(), "normalized length");
        Test.assertEqualMessage(0x00, normalized[0], "final flags low byte");
        Test.assertEqualMessage(0x00, normalized[1], "final flags high byte");
        Test.assertEqualMessage(0x20, normalized[2], "speed low byte");
        Test.assertEqualMessage(0x03, normalized[3], "speed high byte");

        return true;
    }

    (:test)
    static function testPayloadBearingEarlierFragmentIsReassembled(
        logger as Test.Logger
    ) as Boolean {
        var record = new FtmsLogicalRecord([
            [0x05, 0x00, 0x56, 0x34, 0x12]b,
            [0x00, 0x00, 0x20, 0x03]b
        ], 0, 1001);

        var normalizer = new FtmsRecordNormalizer();
        var normalized = normalizer.normalize(record);

        Test.assertMessage(
            normalized != null,
            "payload-bearing earlier fragment should normalize"
        );

        if (normalized == null) {
            return false;
        }

        Test.assertEqualMessage(7, normalized.size(), "normalized length");
        Test.assertEqualMessage(0x04, normalized[0], "flags, total distance present");
        Test.assertEqualMessage(0x00, normalized[1], "final flags high byte");
        Test.assertEqualMessage(0x20, normalized[2], "speed low byte");
        Test.assertEqualMessage(0x03, normalized[3], "speed high byte");
        Test.assertEqualMessage(0x56, normalized[4], "distance low byte");
        Test.assertEqualMessage(0x34, normalized[5], "distance middle byte");
        Test.assertEqualMessage(0x12, normalized[6], "distance high byte");

        return true;
    }

    (:test)
    static function testFieldsAreSerializedInFtmsOrder(
        logger as Test.Logger
    ) as Boolean {
        var record = new FtmsLogicalRecord([
            // Earlier fragment: incline and ramp angle.
            [0x09, 0x00, 0x0A, 0x00, 0x00, 0x00]b,
            // Earlier fragment: total distance.
            [0x05, 0x00, 0x56, 0x34, 0x12]b,
            // Final fragment: instantaneous speed.
            [0x00, 0x00, 0x20, 0x03]b
        ], 0, 1002);

        var normalizer = new FtmsRecordNormalizer();
        var normalized = normalizer.normalize(record);

        Test.assertMessage(
            normalized != null,
            "fields in different fragments should normalize"
        );

        if (normalized == null) {
            return false;
        }

        var expected = [
            0x0C, 0x00,
            0x20, 0x03,
            0x56, 0x34, 0x12,
            0x0A, 0x00,
            0x00, 0x00
        ]b;

        Test.assertEqualMessage(expected.size(), normalized.size(), "normalized length");

        for (var i = 0; i < expected.size(); i += 1) {
            Test.assertEqualMessage(
                expected[i],
                normalized[i],
                "normalized byte " + i
            );
        }

        return true;
    }

    (:test)
    static function testTruncatedFieldDoesNotNormalize(
        logger as Test.Logger
    ) as Boolean {
        var record = new FtmsLogicalRecord([
            // Total distance requires three bytes, but only two are present.
            [0x05, 0x00, 0x56, 0x34]b,
            [0x00, 0x00, 0x20, 0x03]b
        ], 0, 1003);

        var normalizer = new FtmsRecordNormalizer();

        Test.assertMessage(
            normalizer.normalize(record) == null,
            "truncated field should not normalize"
        );

        return true;
    }

    (:test)
    static function testTruncatedFinalSpeedDoesNotNormalize(
        logger as Test.Logger
    ) as Boolean {
        var record = new FtmsLogicalRecord([
            [0x01, 0x00]b,
            [0x00, 0x00, 0x20]b
        ], 0, 1004);

        var normalizer = new FtmsRecordNormalizer();

        Test.assertMessage(
            normalizer.normalize(record) == null,
            "truncated final speed should not normalize"
        );

        return true;
    }
}
