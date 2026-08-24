import Toybox.Lang;

// Collects FTMS notification boundaries. The parser must receive a complete
// logical record, not a notification fragment. Field-level reassembly remains
// deliberately separate from this boundary tracker because More Data changes
// the presence of instantaneous speed on the final notification.
class FtmsRecordAssembler {
    private var _fragments as Array<ByteArray>;

    function initialize() {
        _fragments = [];
    }

    function append(
        bytes as ByteArray,
        receivedAtMs as Number
    ) as FtmsLogicalRecord? {
        var reader = new FtmsByteReader(bytes);
        var flags = reader.readU16LE();

        if (flags == null) {
            discard();
            return null;
        }

        _fragments.add(bytes);

        if ((flags & FtmsConstants.FLAG_MORE_DATA) != 0) {
            return null;
        }

        var complete = new FtmsLogicalRecord(
            _fragments,
            flags,
            receivedAtMs
        );
        _fragments = [];
        return complete;
    }

    function discard() as Void {
        _fragments = [];
    }

    function hasIncompleteRecord() as Boolean {
        return _fragments.size() != 0;
    }

    function incompleteFragmentCount() as Number {
        return _fragments.size();
    }
}
