import '../models/backup_info.dart';

abstract class IBackupRepository {
  Future<BackupFileInfo> createBackup({
    required String storeId,
    String? password,
    String? targetDirectoryPath,
  });

  Future<List<BackupFileInfo>> listBackups({String? directoryPath});

  Future<List<String>> getSuggestedBackupDirectories();

  Future<BackupFileInfo?> inspectBackupFile(String filePath);

  Future<bool> validateBackup(
    String filePath, {
    String? password,
  });

  Future<void> restoreBackup(
    String filePath, {
    String? password,
  });

  Future<bool> deleteBackup(String filePath);

  Future<void> resetDatabaseToInitial({String storeId = 'store-default-01'});
}
