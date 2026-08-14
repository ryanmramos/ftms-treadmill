import Toybox.Lang;

class FtmsParser {
    private function skipPresentField(
        reader as FtmsByteReader,
        flags as Number,
        flag as Number,
        byteCount as Number,
        fieldName as String,
        sample as FtmsSample
    ) as Boolean {
        if ((flags & flag) == 0) {
            return true;
        }

        if (!reader.skip(byteCount)) {
            sample.parseWarnings.add("truncated " + fieldName);
            return false;
        }

        return true;
    }

    function parse(
        bytes as ByteArray, receivedAtMs as Number
    ) as FtmsSample {
        var reader = new FtmsByteReader(bytes);
        var flags = reader.readU16LE();

        if (flags == null) {
            var sample = new FtmsSample(0, receivedAtMs, bytes.size());
            sample.parseWarnings.add("truncated flags");
            return sample;
        }

        var sample = new FtmsSample(flags, receivedAtMs, bytes.size());

        if ((flags & FtmsConstants.RESERVED_FLAGS_MASK) != 0) {
            sample.parseWarnings.add("reserved treadmill data flags set");
            return sample;
        }

        // speed block.
        // if MORE_DATA flag is clear, next two bytes are instantaneous
        // speed. if flag is set, speed field is omitted from this
        // packet (not 0 and not an error, just absent)
        if ((flags & FtmsConstants.FLAG_MORE_DATA) == 0) {
            var rawSpeed = reader.readU16LE();

            if (rawSpeed == null) {
                sample.parseWarnings.add("truncated instantaneous speed");
                return sample;
            }

            // rawSpeed is hundredths of km/h, converting to m/s
            // divides by 3.6, so 100 * 3.6 = 360
            sample.speedMps = rawSpeed / 360.0;
        }

        // average speed block (skipping)
        if (!skipPresentField(
            reader, flags, FtmsConstants.FLAG_AVERAGE_SPEED_PRESENT,
            2, "average speed", sample
        )) {
            return sample;
        }

        // total distance block
        if ((flags & FtmsConstants.FLAG_TOTAL_DISTANCE_PRESENT) != 0) {
            var rawDistanceM = reader.readU24LE();

            if (rawDistanceM == null) {
                sample.parseWarnings.add("truncated total distance");
                return sample;
            }

            sample.totalDistanceM = rawDistanceM.toFloat();
        }

        // incline and ramp angle block
        if ((flags & FtmsConstants.FLAG_INCLINE_AND_RAMP_ANGLE_PRESENT) != 0) {
            var rawIncline = reader.readS16LE();

            if (rawIncline == null) {
                sample.parseWarnings.add("truncated incline");
                return sample;
            }

            var rawRampAngle = reader.readS16LE();

            if (rawRampAngle == null) {
                sample.parseWarnings.add("truncated ramp angle");
                return sample;
            }

            // FTMS reserves signed 16-bit value 0x7FFF for unavailable incline data
            // (see specification)
            if (rawIncline == FtmsConstants.INCLINE_DATA_NOT_AVAILABLE) {
                sample.parseWarnings.add("incline data unavailable");
            } else {
                sample.inclinePercent = rawIncline.toFloat() / 10.0;
            }
        }

        // unsupported flags below
        if (!skipPresentField(
            reader, flags, FtmsConstants.FLAG_ELEVATION_GAIN_PRESENT,
            4, "elevation gain", sample
        )) {
            return sample;
        }

        if (!skipPresentField(
            reader, flags, FtmsConstants.FLAG_INSTANTANEOUS_PACE_PRESENT,
            2, "instantaneous pace", sample
        )) {
            return sample;
        }

        if (!skipPresentField(
            reader, flags, FtmsConstants.FLAG_AVERAGE_PACE_PRESENT,
            2, "average pace", sample
        )) {
            return sample;
        }

        if (!skipPresentField(
            reader, flags, FtmsConstants.FLAG_EXPENDED_ENERGY_PRESENT,
            5, "expended energy", sample
        )) {
            return sample;
        }

        if (!skipPresentField(
            reader, flags, FtmsConstants.FLAG_HEART_RATE_PRESENT,
            1, "heart rate", sample
        )) {
            return sample;
        }

        if (!skipPresentField(
            reader, flags, FtmsConstants.FLAG_METABOLIC_EQUIVALENT_PRESENT,
            1, "metabolic equivalent", sample
        )) {
            return sample;
        }

        if (!skipPresentField(
            reader, flags, FtmsConstants.FLAG_ELAPSED_TIME_PRESENT,
            2, "elapsed time", sample
        )) {
            return sample;
        }

        if (!skipPresentField(
            reader, flags, FtmsConstants.FLAG_REMAINING_TIME_PRESENT,
            2, "remaining time", sample
        )) {
            return sample;
        }

        if (!skipPresentField(
            reader, flags, FtmsConstants.FLAG_FORCE_ON_BELT_AND_POWER_OUTPUT_PRESENT,
            4, "force on belt and power output", sample
        )) {
            return sample;
        }

        // final check
        if (reader.remaining() != 0) {
            sample.parseWarnings.add("unexpected trailing treadmill data");
        }

        return sample;
    }
}