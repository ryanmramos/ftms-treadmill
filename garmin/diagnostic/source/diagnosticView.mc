import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// one live screen: connection state, decoded values, the last raw packet in
// hex, the first parse problem, and the last transport and storage events
class diagnosticView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        var app = getApp();
        var coordinator = app.coordinator;
        var tap = app.tap;
        var state = coordinator.getState();
        var lines = [stateName(state)] as Array<String>;

        if (state == FtmsConnectionCoordinator.STATE_SCANNING) {
            lines.add(coordinator.getScanCandidates().size() + " FTMS seen, START picks");
        }

        var sample = coordinator.getLatestSample();

        if (sample != null) {
            lines.add(
                orDashes(sample.speedMps, 3.6, "%.1f") + " km/h  " +
                orDashes(sample.inclinePercent, 1.0, "%.1f") + " %"
            );
            lines.add(orDashes(sample.totalDistanceM, 1.0, "%.0f") + " m total");

            if (sample.parseErrors.size() > 0) {
                lines.add("error: " + sample.parseErrors[0]);
            } else if (sample.parseWarnings.size() > 0) {
                lines.add("warn: " + sample.parseWarnings[0]);
            }
        }

        var bytes = tap.lastBytes;

        if (bytes != null) {
            lines.add("packet " + tap.packetCount + ", " + bytes.size() + " bytes");
            // eight bytes per row keeps the hex inside the round screen
            for (var start = 0; start < bytes.size(); start += 8) {
                var end = start + 8 < bytes.size() ? start + 8 : bytes.size();
                lines.add(hex(bytes.slice(start, end)));
            }
        }

        lines.addAll(tap.events);
        lines.add(app.storageStatus);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var font = Graphics.FONT_XTINY;
        var lineHeight = dc.getFontHeight(font);
        var y = (dc.getHeight() - lines.size() * lineHeight) / 2;

        for (var i = 0; i < lines.size(); i += 1) {
            dc.drawText(dc.getWidth() / 2, y, font, lines[i], Graphics.TEXT_JUSTIFY_CENTER);
            y += lineHeight;
        }
    }

    private function stateName(state as Number) as String {
        var names = [
            "UNCONFIGURED", "SCANNING", "CONNECTING", "DISCOVERING",
            "SUBSCRIBING", "READY", "STALE", "BACKOFF"
        ] as Array<String>;
        return state >= 0 && state < names.size() ? names[state] : "STATE " + state;
    }

    private function orDashes(value as Float?, scale as Float, format as String) as String {
        return value != null ? (value * scale).format(format) : "--";
    }

    private function hex(bytes as ByteArray) as String {
        var text = "";

        for (var i = 0; i < bytes.size(); i += 1) {
            text += (i == 0 ? "" : " ") + bytes[i].format("%02X");
        }

        return text;
    }
}
