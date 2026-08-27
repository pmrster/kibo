namespace Kibo.App.Views;

/// <summary>
/// The mode display strings from <c>ConverterView.swift</c>: the short picker labels, the RESULT
/// badge, and the four Thai tooltips — the one place Thai appears in the chrome, and deliberately
/// so (four labels that terse cannot say what separates Both from Mixed).
/// </summary>
internal static class ModeLabels
{
    public static string Label(ConversionMode mode) => mode switch
    {
        ConversionMode.SwapAll => "Both",
        ConversionMode.EnglishToThai => "EN → TH",
        ConversionMode.ThaiToEnglish => "TH → EN",
        ConversionMode.Mixed => "Mixed",
        _ => "",
    };

    public static string Badge(ConversionMode mode) => mode switch
    {
        ConversionMode.SwapAll => "everything, both directions",
        ConversionMode.EnglishToThai => "EN → TH",
        ConversionMode.ThaiToEnglish => "TH → EN",
        ConversionMode.Mixed => "only what looks mistyped",
        _ => "",
    };

    /// <summary>Verbatim from <c>ConverterView.helpText(for:)</c>.</summary>
    public static string HelpText(ConversionMode mode) => mode switch
    {
        ConversionMode.SwapAll =>
            "แปลงทุกส่วนพร้อมกันทั้งสองทาง — ไทย→อังกฤษ และ อังกฤษ→ไทย "
            + "ใช้เมื่อรู้ว่าพิมพ์ผิดทั้งหมด รวมถึงตอนที่ผิดคนละทางในประโยคเดียวกัน "
            + "ข้อความที่ถูกอยู่แล้วจะถูกแปลงไปด้วย",
        ConversionMode.EnglishToThai =>
            "ถือว่าทั้งข้อความคือการพิมพ์อังกฤษขณะเปิดแป้นไทย แล้วแปลงเป็นไทยทั้งหมด ไม่มีการเลือกให้",
        ConversionMode.ThaiToEnglish =>
            "ถือว่าทั้งข้อความคือการพิมพ์ไทยขณะเปิดแป้นอังกฤษ แล้วแปลงเป็นอังกฤษทั้งหมด ไม่มีการเลือกให้",
        ConversionMode.Mixed =>
            "แปลงเฉพาะส่วนที่สะกดผิดในภาษาของตัวเอง คำที่ถูกอยู่แล้ว ตัวเลข และเครื่องหมาย จะไม่ถูกแตะต้อง ปลอดภัยที่สุด แต่จะปล่อยผ่านคำที่บังเอิญสะกดถูกในอีกภาษา",
        _ => "",
    };
}
