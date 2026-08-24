import Toybox.Lang;

class ReplayFtmsScheduler {
    private var _listener as FtmsSchedulerListener?;
    private var _scheduledDelayMs as Number?;
    private var _cancelCount as Number;

    function initialize() {
        _listener = null;
        _scheduledDelayMs = null;
        _cancelCount = 0;
    }

    function setListener(listener as FtmsSchedulerListener) as Void {
        _listener = listener;
    }

    function schedule(delayMs as Number) as Void {
        _scheduledDelayMs = delayMs;
    }

    function cancel() as Void {
        _scheduledDelayMs = null;
        _cancelCount += 1;
    }

    function emit() as Void {
        _scheduledDelayMs = null;

        if (_listener != null) {
            _listener.onScheduledWork();
        }
    }

    function getScheduledDelayMs() as Number? {
        return _scheduledDelayMs;
    }

    function getCancelCount() as Number {
        return _cancelCount;
    }
}
