import Toybox.Lang;
import Toybox.Test;

class FtmsByteReaderTest {
    (:test)
    static function testU16DoesNotConsumeTruncatedInput(
        logger as Test.Logger
    ) as Boolean {
        var reader = new FtmsByteReader([0x34]b);

        Test.assertMessage(
            reader.readU16LE() == null,
            "truncated U16 should return null"
        );
        Test.assertEqualMessage(
            1, reader.remaining(),
            "truncated U16 should not advance the cursor"
        );

        return true;
    }

    (:test)
    static function testU24DoesNotConsumeTruncatedInput(
        logger as Test.Logger
    ) as Boolean {
        var reader = new FtmsByteReader([0x56, 0x34]b);

        Test.assertMessage(
            reader.readU24LE() == null,
            "truncated U24 should return null"
        );
        Test.assertEqualMessage(
            2, reader.remaining(),
            "truncated U24 should not advance the cursor"
        );

        return true;
    }

    (:test)
    static function testSkipDoesNotConsumeTruncatedInput(
        logger as Test.Logger
    ) as Boolean {
        var reader = new FtmsByteReader([0x01, 0x02]b);

        Test.assertMessage(
            !reader.skip(3), "truncated skip should return false"
        );
        Test.assertEqualMessage(
            2, reader.remaining(),
            "truncated skip should not advance the cursor"
        );

        return true;
    }

    (:test)
    static function testS16DecodesNegativeBoundaries(
        logger as Test.Logger
    ) as Boolean {
        var reader = new FtmsByteReader([
            0xFF, 0xFF,
            0x00, 0x80
        ]b);

        Test.assertEqualMessage(-1, reader.readS16LE(), "negative one");
        Test.assertEqualMessage(-32768, reader.readS16LE(), "minimum signed 16-bit");

        return true;
    }

    (:test)
    static function testReadBytesReturnsSliceAndAdvances(
        logger as Test.Logger
    ) as Boolean {
        var reader = new FtmsByteReader([0xAA, 0x56, 0x34, 0x12]b);

        Test.assertEqualMessage(0xAA, reader.readU8(), "prefix byte");

        var bytes = reader.readBytes(3);

        Test.assertMessage(bytes != null, "readBytes should return a slice");

        if (bytes == null) {
            return false;
        }

        Test.assertEqualMessage(3, bytes.size(), "slice length");
        Test.assertEqualMessage(0x56, bytes[0], "slice first byte");
        Test.assertEqualMessage(0x34, bytes[1], "slice second byte");
        Test.assertEqualMessage(0x12, bytes[2], "slice third byte");
        Test.assertEqualMessage(0, reader.remaining(), "reader advanced");

        return true;
    }

    (:test)
    static function testReadBytesDoesNotConsumeTruncatedInput(
        logger as Test.Logger
    ) as Boolean {
        var reader = new FtmsByteReader([0x56, 0x34]b);

        Test.assertMessage(
            reader.readBytes(3) == null,
            "truncated readBytes should return null"
        );
        Test.assertEqualMessage(
            2, reader.remaining(),
            "truncated readBytes should not advance the cursor"
        );

        return true;
    }
}
