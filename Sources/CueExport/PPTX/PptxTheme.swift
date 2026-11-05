/// A plain theme (Office-like colours, the system font). Exported slides
/// carry their own colours and fonts on every run, so the theme only
/// matters for text the user adds later in PowerPoint.
enum PptxTheme {
    static func xml(name: String, font: String = "Helvetica Neue") -> String {
        let colours = [
            ("dk1", "000000"), ("lt1", "FFFFFF"), ("dk2", "1F2328"), ("lt2", "EEECE8"),
            ("accent1", "2F7BFF"), ("accent2", "B36BFF"), ("accent3", "38E1FF"), ("accent4", "34C759"),
            ("accent5", "FFB35E"), ("accent6", "FF453A"), ("hlink", "2F7BFF"), ("folHlink", "8E6BFF"),
        ]
        let scheme = colours.map { #"<a:\#($0.0)><a:srgbClr val="\#($0.1)"/></a:\#($0.0)>"# }.joined()
        let fonts = #"<a:latin typeface="\#(font)"/><a:ea typeface=""/><a:cs typeface=""/>"#
        let solid = #"<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>"#
        let line = #"<a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>"#
        let effect = "<a:effectStyle><a:effectLst/></a:effectStyle>"
        return PptxStaticParts.header
            + #"<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="\#(XMLText.escape(name))">"#
            + "<a:themeElements><a:clrScheme name=\"Cue\">\(scheme)</a:clrScheme>"
            + "<a:fontScheme name=\"Cue\"><a:majorFont>\(fonts)</a:majorFont><a:minorFont>\(fonts)</a:minorFont></a:fontScheme>"
            + "<a:fmtScheme name=\"Cue\">"
            + "<a:fillStyleLst>\(solid)\(solid)\(solid)</a:fillStyleLst>"
            + "<a:lnStyleLst>\(line)\(line)\(line)</a:lnStyleLst>"
            + "<a:effectStyleLst>\(effect)\(effect)\(effect)</a:effectStyleLst>"
            + "<a:bgFillStyleLst>\(solid)\(solid)\(solid)</a:bgFillStyleLst>"
            + "</a:fmtScheme></a:themeElements><a:objectDefaults/><a:extraClrSchemeLst/></a:theme>"
    }
}
