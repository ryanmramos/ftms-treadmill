import Toybox.Lang;

typedef FtmsSchedulerListener as interface {
    function onScheduledWork() as Void;
};

typedef FtmsScheduler as interface {
    function setListener(listener as FtmsSchedulerListener) as Void;
    function schedule(delayMs as Number) as Void;
    function cancel() as Void;
};
