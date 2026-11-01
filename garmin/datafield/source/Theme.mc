import Toybox.Graphics;

// visual tokens for the data field, taken from the design canvas (FR265, 416px round).
// all positions are fractions of the screen so the FR265S (360px) uses the same layout.
// rules: true black ground, white values, one gray for labels and units, amber only for
// stale and not found. a treadmill glyph marks treadmill-sourced values. unavailable is "--", never zero.
module Theme {
    // colors (24-bit rgb)
    const BACKGROUND = 0x000000;
    const TEXT = 0xFFFFFF;
    const TEXT_DIM = 0x9A9A9A;
    const HAIRLINE = 0x2A2A2A;
    const ACCENT = 0xFFB020;

    // vertical positions, fraction of screen height
    const HEADER_Y = 0.103;     // glyph and incline, centered
    const PACE_Y = 0.38;        // hero pace, centered
    const CAPTION_Y = 0.615;    // pace unit while live, state word otherwise
    const RULE_Y = 0.697;       // hairline above the speed and distance columns
    const COLUMNS_Y = 0.786;    // speed and distance, centered

    // horizontal geometry, fraction of screen width
    const RULE_INSET = 0.173;   // hairline and column divider span
    const GLYPH_SIZE = 0.072;
    const GLYPH_STROKE = 0.075; // fraction of glyph size

    // garmin built-in fonts: confirm sizes in the simulator before shipping
    const FONT_PACE = Graphics.FONT_NUMBER_THAI_HOT;
    const FONT_VALUE = Graphics.FONT_NUMBER_MEDIUM;
    const FONT_LABEL = Graphics.FONT_XTINY;
    const FONT_HEADER = Graphics.FONT_SMALL; // incline beside the glyph

    // treadmill glyph on a 24 unit grid: belt is a rounded rect, post is a polyline.
    // solid belt when live, outline otherwise. a diagonal slash marks lost and not found.
    const GLYPH_BELT = [2.5, 15.0, 19.0, 4.5, 2.25]; // x, y, w, h, radius
    const GLYPH_POST = [[17.5, 15.0], [15.5, 5.5], [11.0, 5.5]];
    const GLYPH_SLASH = [[3.0, 3.0], [21.0, 21.0]];
}
