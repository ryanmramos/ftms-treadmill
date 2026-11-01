import Toybox.Lang;

// records coordinator edges so tests can assert on them
class RecordingCoordinatorListener {
    var states as Array<Number>;
    var lostCount as Number;
    var restoredCount as Number;

    function initialize() {
        states = [];
        lostCount = 0;
        restoredCount = 0;
    }

    function onStateChanged(state as Number) as Void {
        states.add(state);
    }

    function onConnectionLost() as Void {
        lostCount += 1;
    }

    function onConnectionRestored() as Void {
        restoredCount += 1;
    }
}
