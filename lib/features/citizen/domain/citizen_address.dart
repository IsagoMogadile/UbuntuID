/// Mirrors `citizen_addresses` -- a citizen's own current residential
/// address, previously seeded for every citizen but never surfaced
/// anywhere in the app.
class CitizenAddress {
  const CitizenAddress({
    required this.addressType,
    required this.isCurrent,
    this.unitNumber,
    this.streetNumber,
    this.streetName,
    this.suburb,
    this.city,
    this.municipality,
    this.province,
    this.postalCode,
  });

  final String addressType;
  final bool isCurrent;
  final String? unitNumber;
  final String? streetNumber;
  final String? streetName;
  final String? suburb;
  final String? city;
  final String? municipality;
  final String? province;
  final String? postalCode;

  String get formatted {
    final parts = [
      if (unitNumber != null && unitNumber!.isNotEmpty) 'Unit $unitNumber',
      [streetNumber, streetName].where((p) => p != null && p.isNotEmpty).join(' '),
      suburb,
      city,
      province,
      postalCode,
    ].whereType<String>().where((p) => p.isNotEmpty);
    return parts.isEmpty ? 'No address on file' : parts.join(', ');
  }
}
