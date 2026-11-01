import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// full-screen treadmill data field, drawn to the design canvas (see Theme.mc).
// BLE, settings, and FIT wiring remain WIP: every reading is "--" and the state is
// searching until a coordinator feeds the fields below. partial-screen layout is not drawn yet.
class ftmsDataFieldView extends WatchUi.DataField {
    // what the user sees; map from FtmsConnectionCoordinator states when it is wired in
    static const VS_SEARCHING = 0;
    static const VS_CONNECTING = 1;
    static const VS_LIVE = 2;
    static const VS_STALE = 3;
    static const VS_LOST = 4;
    static const VS_NOT_FOUND = 5;

    private var _visualState as Number;
    private var _pace as String;
    private var _paceUnit as String;
    private var _speed as String;
    private var _speedUnit as String;
    private var _distance as String;
    private var _distanceUnit as String;
    private var _incline as String;

    function initialize() {
        DataField.initialize();
        _visualState = VS_SEARCHING;
        _pace = "--";
        _paceUnit = "";
        _speed = "--";
        _speedUnit = "";
        _distance = "--";
        _distanceUnit = "";
        _incline = "--";
    }

    function compute(info as Activity.Info) as Void {
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var live = _visualState == VS_LIVE;

        dc.setColor(Theme.TEXT, Theme.BACKGROUND);
        dc.clear();

        // header: glyph with incline beside it
        var glyphSize = (w * Theme.GLYPH_SIZE).toNumber();
        var headerY = (h * Theme.HEADER_Y).toNumber();
        var glyphX = (w * 0.38).toNumber();
        drawGlyph(dc, glyphX, headerY, glyphSize);
        dc.setColor(Theme.TEXT, Theme.BACKGROUND);
        dc.drawText(
            glyphX + glyphSize / 2 + (w * 0.034).toNumber(),
            headerY,
            Theme.FONT_HEADER,
            live ? _incline + "%" : "--",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // hero pace, with the unit or the state word beneath it
        dc.drawText(
            cx,
            (h * Theme.PACE_Y).toNumber(),
            Theme.FONT_PACE,
            live ? _pace : "--",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.setColor(Theme.TEXT_DIM, Theme.BACKGROUND);
        dc.drawText(
            cx,
            (h * Theme.CAPTION_Y).toNumber(),
            Theme.FONT_LABEL,
            live ? _paceUnit : stateWord(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // hairline, then speed and distance split by a vertical rule
        var left = (w * Theme.RULE_INSET).toNumber();
        var right = w - left;
        var columnWidth = (right - left) / 2;
        dc.setPenWidth(1);
        dc.setColor(Theme.HAIRLINE, Theme.BACKGROUND);
        var ruleY = (h * Theme.RULE_Y).toNumber();
        var columnsY = (h * Theme.COLUMNS_Y).toNumber();
        dc.drawLine(left, ruleY, right, ruleY);
        dc.drawLine(cx, ruleY + (h * 0.02).toNumber(), cx, columnsY + (h * 0.075).toNumber());

        drawColumn(dc, left + columnWidth / 2, columnsY, live ? _speed : "--", _speedUnit);
        drawColumn(dc, right - columnWidth / 2, columnsY, live ? _distance : "--", _distanceUnit);
    }

    // value over a dim unit label, centered on x
    private function drawColumn(dc as Dc, x as Number, y as Number, value as String, unit as String) as Void {
        var h = dc.getHeight();
        dc.setColor(Theme.TEXT, Theme.BACKGROUND);
        dc.drawText(x, y - (h * 0.02).toNumber(), Theme.FONT_VALUE, value, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.TEXT_DIM, Theme.BACKGROUND);
        dc.drawText(x, y + (h * 0.055).toNumber(), Theme.FONT_LABEL, unit, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // treadmill glyph: solid belt when live, outline otherwise, slash when lost or not found.
    // color follows state: white live and connecting, gray searching and lost, amber stale and not found.
    private function drawGlyph(dc as Dc, cx as Number, cy as Number, size as Number) as Void {
        var s = size / 24.0;
        var ox = cx - size / 2;
        var oy = cy - size / 2;
        var color = Theme.TEXT;
        if (_visualState == VS_SEARCHING || _visualState == VS_LOST) {
            color = Theme.TEXT_DIM;
        } else if (_visualState == VS_STALE || _visualState == VS_NOT_FOUND) {
            color = Theme.ACCENT;
        }

        dc.setColor(color, Theme.BACKGROUND);
        var pen = (size * Theme.GLYPH_STROKE).toNumber();
        dc.setPenWidth(pen < 1 ? 1 : pen);

        var belt = Theme.GLYPH_BELT;
        var bx = (ox + belt[0] * s).toNumber();
        var by = (oy + belt[1] * s).toNumber();
        var bw = (belt[2] * s).toNumber();
        var bh = (belt[3] * s).toNumber();
        var br = (belt[4] * s).toNumber();
        if (_visualState == VS_LIVE) {
            dc.fillRoundedRectangle(bx, by, bw, bh, br);
        } else {
            dc.drawRoundedRectangle(bx, by, bw, bh, br);
        }

        var post = Theme.GLYPH_POST;
        for (var i = 0; i < post.size() - 1; i++) {
            dc.drawLine(
                (ox + post[i][0] * s).toNumber(), (oy + post[i][1] * s).toNumber(),
                (ox + post[i + 1][0] * s).toNumber(), (oy + post[i + 1][1] * s).toNumber()
            );
        }

        if (_visualState == VS_LOST || _visualState == VS_NOT_FOUND) {
            var slash = Theme.GLYPH_SLASH;
            if (_visualState == VS_LOST) {
                dc.setColor(Theme.TEXT, Theme.BACKGROUND);
            }
            dc.drawLine(
                (ox + slash[0][0] * s).toNumber(), (oy + slash[0][1] * s).toNumber(),
                (ox + slash[1][0] * s).toNumber(), (oy + slash[1][1] * s).toNumber()
            );
        }
    }

    // short state word shown where the pace unit goes while not live
    private function stateWord() as String {
        if (_visualState == VS_SEARCHING) {
            return "SEARCHING";
        } else if (_visualState == VS_CONNECTING) {
            return "CONNECTING";
        } else if (_visualState == VS_STALE) {
            return "NO DATA";
        } else if (_visualState == VS_LOST) {
            return "DISCONNECTED";
        }
        return "NOT FOUND, RESELECT";
    }
}
