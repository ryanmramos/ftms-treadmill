import Toybox.Lang;
import Toybox.WatchUi;

// START opens the treadmill picker, MENU forgets the saved treadmill and rescans
class diagnosticDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        var candidates = getApp().coordinator.getScanCandidates();

        if (candidates.size() == 0) {
            return true;
        }

        var menu = new WatchUi.Menu2({:title => "Select treadmill"});

        for (var i = 0; i < candidates.size(); i += 1) {
            var candidate = candidates[i];
            var name = candidate.name;
            menu.addItem(new WatchUi.MenuItem(
                name != null ? name : "unnamed", candidate.rssi + " dBm", i, null
            ));
        }

        WatchUi.pushView(menu, new PickerDelegate(candidates), WatchUi.SLIDE_UP);
        return true;
    }

    function onMenu() as Boolean {
        getApp().forget();
        return true;
    }
}

class PickerDelegate extends WatchUi.Menu2InputDelegate {
    // snapshot of the list the menu was built from, so indexes stay valid
    private var _candidates as Array<FtmsScanCandidate>;

    function initialize(candidates as Array<FtmsScanCandidate>) {
        Menu2InputDelegate.initialize();
        _candidates = candidates;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var index = item.getId() as Number;
        getApp().select(_candidates[index].device);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
