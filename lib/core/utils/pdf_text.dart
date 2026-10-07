/// The `pdf` package's built-in fonts (Helvetica, Times, Courier) only cover
/// Latin-1 -- dashes, bullets and curly quotes silently drop out of the
/// rendered PDF. Swap them for plain equivalents before any text reaches a
/// PDF page, rather than bundling a font asset just for punctuation.
String pdfSafe(String text) => text
    .replaceAll('—', '-') // em dash
    .replaceAll('–', '-') // en dash
    .replaceAll('•', '-') // bullet
    .replaceAll('‘', "'")
    .replaceAll('’', "'")
    .replaceAll('“', '"')
    .replaceAll('”', '"')
    .replaceAll('…', '...');
