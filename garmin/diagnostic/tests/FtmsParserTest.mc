import Toybox.Lang;
import Toybox.Test;

class FtmsParserTest {
    (:test)
    static function testFlagsOnlyPacket(logger as Test.Logger) as Boolean {
        var parser = new FtmsParser();
        var sample = parser.parse([0x01, 0x00]b, 1234);

        Test.assertEqualMessage(0x0001, sample.flags, "flags");
        Test.assertEqualMessage(1234, sample.receivedAtMs, "received timestamp");
        Test.assertEqualMessage(2, sample.rawLength, "raw packet length");
        Test.assertMessage(sample.speedMps == null, "speed should be absent");
        Test.assertEqualMessage(0, sample.parseWarnings.size(), "warning count");

        return true;
    }

    (:test)
    static function testMvpMetricsPacket(logger as Test.Logger) as Boolean {
        var parser = new FtmsParser();

        // Flags: distance + incline/ramp angle. Speed is present because More Data is clear
        // Speed: 800 = 8.00 km/h
        // Distance: 1,193,046 m = 0x123456
        // Incline: -15 = -1.5%
        // Ramp angle: 0
        var bytes = [
            0x0C, 0x00,
            0x20, 0x03,
            0x56, 0x34, 0x12,
            0xF1, 0xFF,
            0x00, 0x00
        ]b;

        var sample = parser.parse(bytes, 5678);

        Test.assertEqualMessage(0x000C, sample.flags, "flags");
        Test.assertEqualMessage(5678, sample.receivedAtMs, "received timestamp");
        Test.assertEqualMessage(11, sample.rawLength, "raw packet length");
        Test.assertMessage(sample.speedMps != null, "speed should be present");
        Test.assertMessage(sample.totalDistanceM != null, "distance should be present");
        Test.assertMessage(sample.inclinePercent != null, "incline should be present");
        Test.assertMessage(
            sample.speedMps >= 2.22 && sample.speedMps <= 2.23,
            "speed in meters per second"
        );
        Test.assertEqualMessage(1193046.0, sample.totalDistanceM, "distance in meters");
        Test.assertEqualMessage(-1.5, sample.inclinePercent, "incline percent");
        Test.assertEqualMessage(0, sample.parseWarnings.size(), "warning count");

        return true;
    }

    (:test)
    static function testTruncatedInstantaneousSpeed(logger as Test.Logger) as Boolean {
        var parser = new FtmsParser();

        // Flags say instantaneous speed is present, but only one speed byte follows
        var sample = parser.parse([0x00, 0x00, 0x20]b, 9999);

        Test.assertEqualMessage(0x0000, sample.flags, "flags");
        Test.assertMessage(sample.speedMps == null, "speed should be unavailable");
        Test.assertEqualMessage(1, sample.parseWarnings.size(), "warning count");
        Test.assertEqualMessage(
            "truncated instantaneous speed",
            sample.parseWarnings[0],
            "truncation warning"
        );

        return true;
    }

    (:test)
    static function testMoreDataOmitsSpeed(logger as Test.Logger) as Boolean {
        var parser = new FtmsParser();

        // Flags: more data + total distance.
        // Instantaneous speed is omitted; total distance is 1,000 m
        var sample = parser.parse([0x05, 0x00, 0xE8, 0x03, 0x00]b, 1010);

        Test.assertEqualMessage(0x0005, sample.flags, "flags");
        Test.assertMessage(sample.speedMps == null, "speed should be absent");
        Test.assertEqualMessage(1000.0, sample.totalDistanceM, "distance in meters");
        Test.assertEqualMessage(0, sample.parseWarnings.size(), "warning count");

        return true;
    }

    (:test)
    static function testAllStandardOptionalFields(logger as Test.Logger) as Boolean {
        var parser = new FtmsParser();

        // Every defined optional field is present; more data is clear, so speed is present
        var bytes = [
            0xFE, 0x1F,
            0x20, 0x03,
            0x00, 0x00,
            0x2A, 0x00, 0x00,
            0x14, 0x00,
            0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00,
            0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00,
            0x00,
            0x00,
            0x00, 0x00,
            0x00, 0x00,
            0x00, 0x00, 0x00, 0x00
        ]b;

        var sample = parser.parse(bytes, 2020);

        Test.assertEqualMessage(0x1FFE, sample.flags, "flags");
        Test.assertEqualMessage(36, sample.rawLength, "raw packet length");
        Test.assertMessage(
            sample.speedMps >= 2.22 && sample.speedMps <= 2.23,
            "speed in meters per second"
        );
        Test.assertEqualMessage(42.0, sample.totalDistanceM, "distance in meters");
        Test.assertEqualMessage(2.0, sample.inclinePercent, "incline percent");
        Test.assertEqualMessage(0, sample.parseWarnings.size(), "warning count");

        return true;
    }

    (:test)
    static function testReservedFlagsAreRejected(logger as Test.Logger) as Boolean {
        var parser = new FtmsParser();

        // Bit 13 is reserved by FTMS
        var sample = parser.parse([0x00, 0x20]b, 3030);

        Test.assertEqualMessage(0x2000, sample.flags, "flags");
        Test.assertEqualMessage(1, sample.parseWarnings.size(), "warning count");
        Test.assertEqualMessage(
            "reserved treadmill data flags set",
            sample.parseWarnings[0],
            "reserved flag warning"
        );

        return true;
    }

    (:test)
    static function testUnexpectedTrailingData(logger as Test.Logger) as Boolean {
        var parser = new FtmsParser();

        // Valid flags and zero speed, followed by one byte with no matching flag
        var sample = parser.parse([0x00, 0x00, 0x00, 0x00, 0xAA]b, 4040);

        Test.assertEqualMessage(0.0, sample.speedMps, "speed in meters per second");
        Test.assertEqualMessage(1, sample.parseWarnings.size(), "warning count");
        Test.assertEqualMessage(
            "unexpected trailing treadmill data",
            sample.parseWarnings[0],
            "trailing-data warning"
        );

        return true;
    }

    (:test)
    static function testTruncatedSkippedField(logger as Test.Logger) as Boolean {
        var parser = new FtmsParser();

        // Average Speed is flagged as present but only one of its two bytes follows
        var sample = parser.parse([0x02, 0x00, 0x00, 0x00, 0x7F]b, 5050);

        Test.assertEqualMessage(0x0002, sample.flags, "flags");
        Test.assertEqualMessage(0.0, sample.speedMps, "speed in meters per second");
        Test.assertEqualMessage(1, sample.parseWarnings.size(), "warning count");
        Test.assertEqualMessage(
            "truncated average speed",
            sample.parseWarnings[0],
            "truncated skipped-field warning"
        );

        return true;
    }

    (:test)
    static function testZeroMetricsAreValid(logger as Test.Logger) as Boolean {
        var parser = new FtmsParser();
        var sample = parser.parse([
            0x0C, 0x00,
            0x00, 0x00,
            0x00, 0x00, 0x00,
            0x00, 0x00,
            0x00, 0x00
        ]b, 6060);

        Test.assertEqualMessage(0.0, sample.speedMps, "zero speed");
        Test.assertEqualMessage(0.0, sample.totalDistanceM, "zero distance");
        Test.assertEqualMessage(0.0, sample.inclinePercent, "zero incline");
        Test.assertEqualMessage(0, sample.parseWarnings.size(), "warning count");

        return true;
    }

    (:test)
    static function testUnavailableIncline(logger as Test.Logger) as Boolean {
        var parser = new FtmsParser();
        var sample = parser.parse([
            0x08, 0x00,
            0x00, 0x00,
            0xFF, 0x7F,
            0x00, 0x00
        ]b, 7070);

        Test.assertEqualMessage(0.0, sample.speedMps, "zero speed");
        Test.assertMessage(sample.inclinePercent == null, "incline should be unavailable");
        Test.assertEqualMessage(1, sample.parseWarnings.size(), "warning count");
        Test.assertEqualMessage(
            "incline data unavailable",
            sample.parseWarnings[0],
            "unavailable-incline warning"
        );

        return true;
    }

    (:test)
    static function testMaximumUnsignedValues(logger as Test.Logger) as Boolean {
        var parser = new FtmsParser();

        // Flags: total distance present. More Data is clear, so speed is present
        var sample = parser.parse([
            0x04, 0x00,
            0xFF, 0xFF,
            0xFF, 0xFF, 0xFF
        ]b, 8080);

        Test.assertMessage(
            sample.speedMps >= 182.04 && sample.speedMps <= 182.05,
            "maximum speed in meters per second"
        );
        Test.assertEqualMessage(
            16777215.0,
            sample.totalDistanceM,
            "maximum 24-bit distance in meters"
        );
        Test.assertEqualMessage(0, sample.parseWarnings.size(), "warning count");

        return true;
    }
}