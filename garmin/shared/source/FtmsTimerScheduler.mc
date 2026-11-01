import Toybox.Lang;
import Toybox.Timer;

// production scheduler: one pending one-shot delay on a Garmin timer.
// scheduling again replaces the pending delay; cancel clears it.
class FtmsTimerScheduler {
    private var _listener as FtmsSchedulerListener?;
    private var _timer as Timer.Timer;
    private var _pending as Boolean;

    function initialize() {
        _listener = null;
        _timer = new Timer.Timer();
        _pending = false;
    }

    function setListener(listener as FtmsSchedulerListener) as Void {
        _listener = listener;
    }

    function schedule(delayMs as Number) as Void {
        cancel();
        _pending = true;
        _timer.start(method(:onFire), delayMs, false);
    }

    function cancel() as Void {
        if (_pending) {
            _timer.stop();
            _pending = false;
        }
    }

    // public so method(:onFire) can reference it
    function onFire() as Void {
        _pending = false;

        if (_listener != null) {
            _listener.onScheduledWork();
        }
    }
}
