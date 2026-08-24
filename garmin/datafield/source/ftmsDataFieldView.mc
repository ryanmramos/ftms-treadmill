import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Production data-field scaffold. BLE, settings, and FIT wiring remain WIP;
// the placeholder makes the API/permission target buildable while preserving
// the native activity boundary.
class ftmsDataFieldView extends WatchUi.DataField {
    private var _displayValue as String;

    function initialize() {
        DataField.initialize();
        _displayValue = "--";
    }

    function compute(info as Activity.Info) as Void {
        _displayValue = "--";
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() / 2,
            Graphics.FONT_LARGE,
            _displayValue,
            Graphics.TEXT_JUSTIFY_CENTER
        );
        View.onUpdate(dc);
    }
}
