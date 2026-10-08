/// What the public QR verification page may show about a document -- by
/// design nothing that identifies the holder.
class PublicVerificationResult {
  const PublicVerificationResult({
    required this.isIdentity,
    required this.document,
    required this.issuer,
    required this.status,
    this.issuedDate,
    this.expiryDate,
  });

  factory PublicVerificationResult.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) => json[key] == null ? null : DateTime.tryParse(json[key] as String);
    return PublicVerificationResult(
      isIdentity: json['kind'] == 'identity',
      document: json['document'] as String? ?? 'Document',
      issuer: json['issuer'] as String? ?? 'Unknown issuer',
      status: json['status'] as String? ?? 'pending',
      issuedDate: date('issued_date'),
      expiryDate: date('expiry_date'),
    );
  }

  final bool isIdentity;
  final String document;
  final String issuer;
  final String status;
  final DateTime? issuedDate;
  final DateTime? expiryDate;

  bool get isValid => status == 'active';
}
