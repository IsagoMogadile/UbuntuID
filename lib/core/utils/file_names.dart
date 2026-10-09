/// Download file names that say whose file it is, e.g.
/// `Kopano_Mogadile_ID.pdf` or `Kops_Tech_Template.xlsx`.
///
/// Each part keeps its capitalisation; anything that isn't a letter or digit
/// becomes a single underscore ("Driver's Licence" -> "Drivers_Licence",
/// "Kops Tech (Pty) Ltd" -> "Kops_Tech_Pty_Ltd").
String downloadFileName(List<String> parts, String extension) => '${downloadBaseName(parts)}.$extension';

/// [downloadFileName] without the extension.
String downloadBaseName(List<String> parts) {
  final cleaned = [
    for (final part in parts)
      part
          .replaceAll("'", '')
          .replaceAll(RegExp('[^A-Za-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), ''),
  ].where((p) => p.isNotEmpty);
  return cleaned.isEmpty ? 'UbuntuID' : cleaned.join('_');
}

/// A person's first given name and surname, for a file name.
List<String> personFileNameParts(String firstNames, String surname) =>
    [firstNames.trim().split(RegExp(r'\s+')).first, surname];
