/// Mirrors `public.documents`.
class DocumentItem {
  const DocumentItem({
    required this.documentId,
    required this.documentType,
    required this.fileName,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
  });

  final String documentId;
  final String documentType;
  final String fileName;
  final String status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
}
