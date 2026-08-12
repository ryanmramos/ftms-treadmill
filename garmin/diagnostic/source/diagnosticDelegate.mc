import Toybox.Lang;
import Toybox.WatchUi;

class diagnosticDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onMenu() as Boolean {
        WatchUi.pushView(new Rez.Menus.MainMenu(), new diagnosticMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

}