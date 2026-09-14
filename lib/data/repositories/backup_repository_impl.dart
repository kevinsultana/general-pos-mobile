import '../../domain/models/backup_info.dart';
import '../../domain/repositories/i_backup_repository.dart';
import '../services/backup_service.dart';

class BackupRepositoryImpl implements IBackupRepository {
  final BackupService _backupService;

  BackupRepositoryImpl(this._backupService);

  @override
  Future<BackupFileInfo> createBackup({
    required String storeId,
    String? password,
    String? targetDirectoryPath,
  }) {
    return _backupService.createBackup(
      storeId: storeId,
      password: password,
      targetDirectoryPath: targetDirectoryPath,
    );
  }

  @override
  Future<List<BackupFileInfo>> listBackups({String? directoryPath}) {
    return _backupService.listBackups(directoryPath: directoryPath);
  }

  @override
  Future<List<String>> getSuggestedBackupDirectories() {
    return _backupService.getSuggestedBackupDirectories();
  }

  @override
  Future<BackupFileInfo?> inspectBackupFile(String filePath) {
    return _backupService.inspectBackupFile(filePath);
  }

  @override
  Future<bool> validateBackup(String filePath, {String? password}) {
    return _backupService.validateBackup(filePath, password: password);
  }

  @override
  Future<void> restoreBackup(String filePath, {String? password}) {
    return _backupService.restoreBackup(filePath, password: password);
  }

  @override
  Future<bool> deleteBackup(String filePath) {
    return _backupService.deleteBackup(filePath);
  }

  @override
  Future<void> resetDatabaseToInitial({String storeId = 'store-default-01'}) {
    return _backupService.resetDatabaseToInitial(storeId: storeId);
  }
}
