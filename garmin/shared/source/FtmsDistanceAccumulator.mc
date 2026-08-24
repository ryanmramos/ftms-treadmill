import Toybox.Lang;

class FtmsDistanceAccumulator {
    private var _accumulatedM as Float;
    private var _baselineM as Float?;
    private var _started as Boolean;
    private var _paused as Boolean;

    function initialize() {
        _accumulatedM = 0.0;
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

        if (_baselineM == null || totalDistanceM < _baselineM) {
            _baselineM = totalDistanceM;
            return;
        }

        _accumulatedM += totalDistanceM - _baselineM;
        _baselineM = totalDistanceM;
    }

    function getAccumulatedM() as Float {
        return _accumulatedM;
    }

    function hasRawBaseline() as Boolean {
        return _baselineM != null;
    }

    private function rebaseline(totalDistanceM as Float?) as Void {
        _baselineM = totalDistanceM;
    }
}
