import 'package:flutter/material.dart';
import '../../../core/database/local_repository.dart';
import '../../../core/models/shift_model.dart';
import '../../../core/utils/id_generator.dart';

class ShiftController with ChangeNotifier {
  final LocalRepository _repo = LocalRepository();

  ShiftModel? _activeShift;
  List<ShiftModel> _shiftHistory = [];
  bool _isLoading = false;

  ShiftModel? get activeShift => _activeShift;
  bool get hasActiveShift => _activeShift != null;
  List<ShiftModel> get shiftHistory => _shiftHistory;
  bool get isLoading => _isLoading;

  Future<void> checkActiveShift(String tenantId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _activeShift = await _repo.getActiveShift(tenantId);
      _shiftHistory = await _repo.getShifts(tenantId);
    } catch (e) {
      debugPrint('Check active shift error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<ShiftModel> startShift({
    required String tenantId,
    String? branchId,
    required String cashierName,
    required double startingCash,
  }) async {
    final shift = ShiftModel(
      id: IdGenerator.v4(),
      tenantId: tenantId,
      branchId: branchId,
      cashierName: cashierName,
      startingCash: startingCash,
      status: 'OPEN',
      startedAt: DateTime.now().toIso8601String(),
    );

    await _repo.startShift(shift);
    _activeShift = shift;
    await checkActiveShift(tenantId);
    return shift;
  }

  Future<ShiftModel?> closeShift({
    required double actualCash,
  }) async {
    if (_activeShift == null) return null;

    final expectedCash = _activeShift!.expectedCash;
    final discrepancy = actualCash - expectedCash;

    await _repo.closeShift(
      shiftId: _activeShift!.id,
      actualCash: actualCash,
      closingCash: actualCash,
      discrepancy: discrepancy,
    );

    final closedShift = _activeShift!.copyWith(
      status: 'CLOSED',
      actualCash: actualCash,
      closingCash: actualCash,
      discrepancy: discrepancy,
      endedAt: DateTime.now().toIso8601String(),
    );

    final tenantId = _activeShift!.tenantId;
    _activeShift = null;
    await checkActiveShift(tenantId);
    return closedShift;
  }
}
