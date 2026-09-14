class BackupFileInfo {
  final String filePath;
  final String fileName;
  final DateTime createdAt;
  final int fileSizeBytes;
  final String? storeId;
  final String? storeName;
  final int? transactionCount;
  final int? productCount;
  final String? checksum;

  const BackupFileInfo({
    required this.filePath,
    required this.fileName,
    required this.createdAt,
    required this.fileSizeBytes,
    this.storeId,
    this.storeName,
    this.transactionCount,
    this.productCount,
    this.checksum,
  });

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
