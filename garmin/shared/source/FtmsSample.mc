import Toybox.Lang;

// one decoded treadmill reading in canonical units, plus parse diagnostics.
// warnings are informational; any parse error makes the sample invalid.
class FtmsSample {
    var speedMps as Float?;
    var totalDistanceM as Float?;
    var inclinePercent as Float?;
    var flags as Number;
    var receivedAtMs as Number;
    var rawLength as Number;
    var parseWarnings as Array<String>;
    var parseErrors as Array<String>;

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
        parseErrors = [];
    }

    function addWarning(message as String) as Void {
        parseWarnings.add(message);
    }

    function addParseError(message as String) as Void {
        parseErrors.add(message);
    }

    function hasFatalError() as Boolean {
        return parseErrors.size() != 0;
    }

    function isValid() as Boolean {
        return !hasFatalError();
    }

    // folds in an earlier More Data fragment of the same record. values already
    // on this sample win, diagnostics keep arrival order, and More Data is
    // cleared from the merged flags. the earlier sample must not be reused.
    function mergeEarlier(earlier as FtmsSample) as Void {
        if (speedMps == null) {
            speedMps = earlier.speedMps;
        }

        if (totalDistanceM == null) {
            totalDistanceM = earlier.totalDistanceM;
        }

        if (inclinePercent == null) {
            inclinePercent = earlier.inclinePercent;
        }

        flags = (flags | earlier.flags) & ~FtmsConstants.FLAG_MORE_DATA;
        rawLength += earlier.rawLength;
        parseWarnings = earlier.parseWarnings.addAll(parseWarnings);
        parseErrors = earlier.parseErrors.addAll(parseErrors);
    }
}
