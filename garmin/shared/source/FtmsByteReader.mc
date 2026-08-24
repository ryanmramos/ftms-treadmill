import Toybox.Lang;

class FtmsByteReader {
    private var _bytes as ByteArray;
    private var _offset as Number;

    function initialize(bytes as ByteArray) {
        _bytes = bytes;
        _offset = 0;
    }

    // remaining bytes to read in initial ByteArray
    function remaining() as Number {
        return _bytes.size() - _offset;
    }

    // skip byteCount bytes
    function skip(byteCount as Number) as Boolean {
        if (byteCount < 0 || remaining() < byteCount) {
            return false;
        }

        _offset += byteCount;
        return true;
    }

    // read next unsigned byte
    function readU8() as Number? {
        if (remaining() < 1) {
            return null;
        }

        var value = _bytes[_offset];
        _offset += 1;
        return value;
    }

    // read unsigned 16-bit (little endian)
    function readU16LE() as Number? {
        if (remaining() < 2) {
            return null;
        }

        var low = readU8();
        var high = readU8();

        if (low == null || high == null) {
            return null;
        }

        return low | (high << 8);
    }

    // read unsigned 24-bit (little endian)
    function readU24LE() as Number? {
        if (remaining() < 3) {
            return null;
        }

        var low16 = readU16LE();
        var high8 = readU8();

        if (low16 == null || high8 == null) {
            return null;
        }

        return low16 | (high8 << 16);
    }

    // read signed 16-bit (little endian)
    function readS16LE() as Number? {
        var unsigned16 = readU16LE();

        if (unsigned16 == null) {
            return null;
        }

        if (unsigned16 >= 0x8000) {
            return unsigned16 - 0x10000;
        }

        return unsigned16;
    }
}
