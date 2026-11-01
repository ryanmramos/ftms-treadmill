import Toybox.Lang;

// turns FTMS notifications into complete samples. every notification carries
// its own flags, so each one is parsed on arrival. fragments with More Data set
// are held and merged into the notification that clears it.
class FtmsRecordAssembler {
    private var _parser as FtmsParser;
    private var _pending as FtmsSample?;

    function initialize() {
        _parser = new FtmsParser();
        _pending = null;
    }

    // returns the merged sample once a notification clears More Data, else null
    function append(
        bytes as ByteArray,
        receivedAtMs as Number
    ) as FtmsSample? {
        var sample = _parser.parse(bytes, receivedAtMs);
        var moreData = (sample.flags & FtmsConstants.FLAG_MORE_DATA) != 0;
        var pending = _pending;

        if (pending != null) {
            sample.mergeEarlier(pending);
        }

        if (moreData) {
            _pending = sample;
            return null;
        }

        _pending = null;
        return sample;
    }

    // drops a partial record, used on disconnect so fragments never span links
    function discard() as Void {
        _pending = null;
    }

    function hasIncompleteRecord() as Boolean {
        return _pending != null;
    }
}
