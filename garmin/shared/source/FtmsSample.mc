import Toybox.Lang;

class FtmsSample {
    var speedMps as Float?;
    var totalDistanceM as Float?;
    var inclinePercent as Float?;
    var flags as Number;
    var receivedAtMs as Number;
    var rawLength as Number;
    var parseWarnings as Array<String>;

    function initialize(
        flags as Number,
        receivedAtMs as Number,
        rawLength as Number
    ) {
        self.flags = flags;
        self.receivedAtMs = receivedAtMs;
        self.rawLength = rawLength;

        speedMps = null;
        totalDistanceM = null;
        inclinePercent = null;
        parseWarnings = [];
    }
}