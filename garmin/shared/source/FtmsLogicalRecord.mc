import Toybox.Lang;

class FtmsLogicalRecord {
    var fragments as Array<ByteArray>;
    var flags as Number;
    var receivedAtMs as Number;

    function initialize(
        fragments as Array<ByteArray>,
        flags as Number,
        receivedAtMs as Number
    ) {
        self.fragments = fragments;
        self.flags = flags;
        self.receivedAtMs = receivedAtMs;
    }

    function isSingleNotification() as Boolean {
        return fragments.size() == 1;
    }

    function fragmentCount() as Number {
        return fragments.size();
    }
}
