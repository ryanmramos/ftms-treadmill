import Toybox.Lang;

// distance observed while connected, from the treadmill's total distance
// counter. pauses and disconnects rebaseline, so gaps are never bridged.
class FtmsDistanceAccumulator {
    private var _accumulatedM as Float;
    // a distance has been seen since start; until then the value is unavailable
    private var _hasValue as Boolean;
    private var _baselineM as Float?;
    private var _started as Boolean;
    private var _paused as Boolean;

    function initialize() {
        _accumulatedM = 0.0;
        _hasValue = false;
        _baselineM = null;
        _started = false;
        _paused = false;
    }

    function start(totalDistanceM as Float?) as Void {
        if (!_started) {
            _started = true;
            _accumulatedM = 0.0;
        }

        _paused = false;
        rebaseline(totalDistanceM);
    }

    function pause() as Void {
        _paused = true;
    }

    function resume(totalDistanceM as Float?) as Void {
        _paused = false;
        rebaseline(totalDistanceM);
    }

    function disconnect() as Void {
        // Preserve accumulated distance, but do not bridge the unobserved gap.
        _baselineM = null;
    }

    function observe(totalDistanceM as Float?) as Void {
        if (!_started || _paused || totalDistanceM == null) {
            return;
        }

        _hasValue = true;

        if (_baselineM == null || totalDistanceM < _baselineM) {
            _baselineM = totalDistanceM;
            return;
        }

        _accumulatedM += totalDistanceM - _baselineM;
        _baselineM = totalDistanceM;
    }

    // null until a distance has been seen, so the field shows -- and not 0
    function getAccumulatedM() as Float? {
        return _hasValue ? _accumulatedM : null;
    }

    function hasRawBaseline() as Boolean {
        return _baselineM != null;
    }

    private function rebaseline(totalDistanceM as Float?) as Void {
        if (totalDistanceM != null) {
            _hasValue = true;
        }

        _baselineM = totalDistanceM;
    }
}
