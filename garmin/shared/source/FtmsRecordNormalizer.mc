import Toybox.Lang;

class FtmsRecordNormalizer {
    // Read one optional field and keep its raw bytes keyed by its FTMS flag.
    private function readOptionalField(
        reader as FtmsByteReader,
        flags as Number,
        fieldFlag as Number,
        byteCount as Number,
        fields as Dictionary<Number, ByteArray>
    ) as Boolean {
        if ((flags & fieldFlag) == 0) {
            return true;
        }

        // a logical record should contain each flagged field once.
        if (fields[fieldFlag] != null) {
            return false;
        }

        var fieldBytes = reader.readBytes(byteCount);

        if (fieldBytes == null) {
            return false;
        }

        fields[fieldFlag] = fieldBytes;
        return true;
    }

    private function appendOptionalField(
        normalized as ByteArray,
        fields as Dictionary<Number, ByteArray>,
        fieldFlag as Number
    ) as Void {
        var fieldBytes = fields[fieldFlag];

        if (fieldBytes != null) {
            normalized.addAll(fieldBytes);
        }
    }

    function normalize(
        record as FtmsLogicalRecord
    ) as ByteArray? {
        var fragmentCount = record.fragmentCount();

        if (fragmentCount == 0) {
            return null;
        }

        // A single notification is already in parser format. preserve it so
        // FtmsParser can retain diagnostics for malformed single packets.
        if (fragmentCount == 1) {
            return record.fragments[0];
        }

        var lastIndex = fragmentCount - 1;
        var normalizedFlags = 0;
        var speedBytes = new [0]b;
        var hasSpeed = false;
        var fields = {} as Dictionary<Number, ByteArray>;
        var trailingBytes = new [0]b;

        for (var i = 0; i < fragmentCount; i += 1) {
            var reader = new FtmsByteReader(record.fragments[i]);
            var fragmentFlags = reader.readU16LE();
            var isFinalFragment = i == lastIndex;

            if (fragmentFlags == null) {
                return null;
            }

            if (isFinalFragment) {
                if ((fragmentFlags & FtmsConstants.FLAG_MORE_DATA) != 0) {
                    return null;
                }

                // the final fragment is the only fragment that carries speed.
                var fragmentSpeedBytes = reader.readBytes(2);

                if (fragmentSpeedBytes == null) {
                    return null;
                }

                speedBytes = fragmentSpeedBytes;
                hasSpeed = true;
            } else if ((fragmentFlags & FtmsConstants.FLAG_MORE_DATA) == 0) {
                // every non-final fragment must say that more data follows.
                return null;
            }

            // drop MORE_DATA from the merged header. the canonical packet is
            // complete, so its header must describe one complete record.
            normalizedFlags = normalizedFlags |
                (fragmentFlags & 0xFFFE);

            if (!readOptionalField(
                reader, fragmentFlags,
                FtmsConstants.FLAG_AVERAGE_SPEED_PRESENT,
                2, fields
            )) {
                return null;
            }

            if (!readOptionalField(
                reader, fragmentFlags,
                FtmsConstants.FLAG_TOTAL_DISTANCE_PRESENT,
                3, fields
            )) {
                return null;
            }

            if (!readOptionalField(
                reader, fragmentFlags,
                FtmsConstants.FLAG_INCLINE_AND_RAMP_ANGLE_PRESENT,
                4, fields
            )) {
                return null;
            }

            if (!readOptionalField(
                reader, fragmentFlags,
                FtmsConstants.FLAG_ELEVATION_GAIN_PRESENT,
                4, fields
            )) {
                return null;
            }

            if (!readOptionalField(
                reader, fragmentFlags,
                FtmsConstants.FLAG_INSTANTANEOUS_PACE_PRESENT,
                2, fields
            )) {
                return null;
            }

            if (!readOptionalField(
                reader, fragmentFlags,
                FtmsConstants.FLAG_AVERAGE_PACE_PRESENT,
                2, fields
            )) {
                return null;
            }

            if (!readOptionalField(
                reader, fragmentFlags,
                FtmsConstants.FLAG_EXPENDED_ENERGY_PRESENT,
                5, fields
            )) {
                return null;
            }

            if (!readOptionalField(
                reader, fragmentFlags,
                FtmsConstants.FLAG_HEART_RATE_PRESENT,
                1, fields
            )) {
                return null;
            }

            if (!readOptionalField(
                reader, fragmentFlags,
                FtmsConstants.FLAG_METABOLIC_EQUIVALENT_PRESENT,
                1, fields
            )) {
                return null;
            }

            if (!readOptionalField(
                reader, fragmentFlags,
                FtmsConstants.FLAG_ELAPSED_TIME_PRESENT,
                2, fields
            )) {
                return null;
            }

            if (!readOptionalField(
                reader, fragmentFlags,
                FtmsConstants.FLAG_REMAINING_TIME_PRESENT,
                2, fields
            )) {
                return null;
            }

            if (!readOptionalField(
                reader, fragmentFlags,
                FtmsConstants.FLAG_FORCE_ON_BELT_AND_POWER_OUTPUT_PRESENT,
                4, fields
            )) {
                return null;
            }

            // Preserve unknown/trailing bytes so the parser can report them.
            if (reader.remaining() > 0) {
                var fragmentTrailingBytes = reader.readBytes(reader.remaining());

                if (fragmentTrailingBytes == null) {
                    return null;
                }

                trailingBytes.addAll(fragmentTrailingBytes);
            }
        }

        if (!hasSpeed) {
            return null;
        }

        // build the canonical FTMS packet header in little-endian order.
        var normalized = new [0]b;
        normalized.add(normalizedFlags & 0xFF);
        normalized.add((normalizedFlags >> 8) & 0xFF);

        // FtmsParser expects speed first, followed by fields in this order.
        normalized.addAll(speedBytes);
        appendOptionalField(
            normalized, fields, FtmsConstants.FLAG_AVERAGE_SPEED_PRESENT
        );
        appendOptionalField(
            normalized, fields, FtmsConstants.FLAG_TOTAL_DISTANCE_PRESENT
        );
        appendOptionalField(
            normalized, fields,
            FtmsConstants.FLAG_INCLINE_AND_RAMP_ANGLE_PRESENT
        );
        appendOptionalField(
            normalized, fields, FtmsConstants.FLAG_ELEVATION_GAIN_PRESENT
        );
        appendOptionalField(
            normalized, fields, FtmsConstants.FLAG_INSTANTANEOUS_PACE_PRESENT
        );
        appendOptionalField(
            normalized, fields, FtmsConstants.FLAG_AVERAGE_PACE_PRESENT
        );
        appendOptionalField(
            normalized, fields, FtmsConstants.FLAG_EXPENDED_ENERGY_PRESENT
        );
        appendOptionalField(
            normalized, fields, FtmsConstants.FLAG_HEART_RATE_PRESENT
        );
        appendOptionalField(
            normalized, fields, FtmsConstants.FLAG_METABOLIC_EQUIVALENT_PRESENT
        );
        appendOptionalField(
            normalized, fields, FtmsConstants.FLAG_ELAPSED_TIME_PRESENT
        );
        appendOptionalField(
            normalized, fields, FtmsConstants.FLAG_REMAINING_TIME_PRESENT
        );
        appendOptionalField(
            normalized, fields,
            FtmsConstants.FLAG_FORCE_ON_BELT_AND_POWER_OUTPUT_PRESENT
        );
        normalized.addAll(trailingBytes);

        return normalized;
    }
}
