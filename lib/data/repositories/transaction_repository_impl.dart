import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/cart_item.dart';
import '../../domain/models/payment_input.dart';
import '../../domain/repositories/i_transaction_repository.dart';
import '../local/app_database.dart';

class TransactionRepositoryImpl implements ITransactionRepository {
  final AppDatabase _db;
  final Uuid _uuid;
  final bool _isCloudMode;
  final String? _deviceId;

  TransactionRepositoryImpl(
    this._db, [
    Uuid? uuid,
    bool isCloudMode = false,
    String? deviceId,
  ])  : _uuid = uuid ?? const Uuid(),
        _isCloudMode = isCloudMode,
        _deviceId = deviceId;

  @override
  Future<String> completeTransaction({
    required String storeId,
    required String orderType,
    String? queueNumber,
    String? customerId,
    String? promotionId,
    required int subtotal,
    String? discountType,
    int? discountValue,
    required int discountTotal,
    required int roundingAmount,
    required int total,
    required List<CartItem> items,
    required List<PaymentInput> payments,
    String? draftId,
  }) async {
    final now = DateTime.now();
    final transactionId = _uuid.v4();
    final transactionNumber = _generateTransactionNumber(now);

    final expectedRounding = payments
        .where((p) => p.paymentType == 'CASH')
        .fold<int>(0, (sum, p) => sum + p.roundingAmount);

    for (final p in payments) {
      if (p.paymentType != 'CASH' && p.roundingAmount != 0) {
        throw ArgumentError(
          'PRD Bab 21 / INV-013: Cash rounding hanya berlaku untuk metode pembayaran CASH, namun tipe ${p.paymentType} memiliki roundingAmount: ${p.roundingAmount}',
        );
      }
    }

    if (roundingAmount != expectedRounding) {
      throw ArgumentError(
        'PRD Bab 21 Invariant 1: Transaction.roundingAmount ($roundingAmount) harus sama dengan SUM(Payment.roundingAmount) ($expectedRounding)',
      );
    }

    final paidTotal = payments.fold<int>(0, (sum, p) => sum + p.amount);

    return _db.transaction(() async {
      // 1. Insert Completed Transaction
      await _db.into(_db.transactions).insert(
            TransactionsCompanion(
              id: Value(transactionId),
              storeId: Value(storeId),
              transactionNumber: Value(transactionNumber),
              customerId: Value(customerId),
              promotionId: Value(promotionId),
              status: const Value('COMPLETED'),
              orderType: Value(orderType),
              queueNumber: Value(queueNumber),
              subtotal: Value(subtotal),
              discountType: Value(discountType),
              discountValue: Value(discountValue),
              discountTotal: Value(discountTotal),
              roundingAmount: Value(roundingAmount),
              total: Value(total),
              paidTotal: Value(paidTotal),
              createdAt: Value(now),
              completedAt: Value(now),
              updatedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );

      // 2. Insert Transaction Items
      for (final item in items) {
        final itemId = _uuid.v4();
        await _db.into(_db.transactionItems).insert(
              TransactionItemsCompanion(
                id: Value(itemId),
                transactionId: Value(transactionId),
                productId: Value(item.productId),
                variantId: Value(item.variantId),
                productNameSnapshot: Value(item.productName),
                variantNameSnapshot: Value(item.variantName),
                skuSnapshot: Value(item.sku),
                barcodeSnapshot: Value(item.barcode),
                quantity: Value(item.quantity),
                unitPrice: Value(item.unitPrice),
                unitCostSnapshot: Value(item.unitCostSnapshot),
                discountType: Value(item.discountType),
                discountValue: Value(item.discountValue),
                discountAmount: Value(item.discountAmount),
                subtotal: Value(item.subtotal),
                total: Value(item.total),
                createdAt: Value(now),
              ),
              mode: InsertMode.insertOrReplace,
            );

        // 3. Deduct Stock & Record SALE Stock Movement
        // PRD Rule: Stock decreases ONLY upon transaction completion!
        if (item.variantId != null && item.variantId!.isNotEmpty) {
          final variant = await (_db.select(_db.productVariants)
                ..where((tbl) => tbl.id.equals(item.variantId!)))
              .getSingleOrNull();

          if (variant != null) {
            final newVariantStock = variant.stock - item.quantity.round();
            await (_db.update(_db.productVariants)
                  ..where((tbl) => tbl.id.equals(variant.id)))
                .write(ProductVariantsCompanion(
              stock: Value(newVariantStock),
              updatedAt: Value(now),
            ));
          }
        }

        // Always update parent product stock
        final product = await (_db.select(_db.products)
              ..where((tbl) => tbl.id.equals(item.productId)))
            .getSingleOrNull();

        if (product != null) {
          final newStock = product.stock - item.quantity.round();
          await (_db.update(_db.products)
                ..where((tbl) => tbl.id.equals(product.id)))
              .write(ProductsCompanion(
            stock: Value(newStock),
            updatedAt: Value(now),
          ));
        }

        // Ledger row: Signed integer with scale 1000
        await _db.into(_db.stockMovements).insert(
              StockMovementsCompanion(
                id: Value(_uuid.v4()),
                storeId: Value(storeId),
                productId: Value(item.productId),
                variantId: Value(item.variantId),
                type: const Value('SALE'),
                quantityDelta: Value(-(item.quantity * 1000).round()),
                unitCost: Value(item.unitCostSnapshot),
                referenceType: const Value('TRANSACTION'),
                referenceId: Value(transactionId),
                createdAt: Value(now),
              ),
            );
      }

      // 4. Insert Payments
      for (final payment in payments) {
        final paymentId = _uuid.v4();
        final metadataJson = jsonEncode({
          'paymentType': payment.paymentType,
          'tenderedAmount': payment.tenderedAmount,
          'changeAmount': payment.changeAmount,
          'referenceNumber': payment.referenceNumber,
          'note': payment.note,
        });

        await _db.into(_db.payments).insert(
              PaymentsCompanion(
                id: Value(paymentId),
                transactionId: Value(transactionId),
                paymentMethodId: Value(payment.paymentMethodId),
                amount: Value(payment.amount),
                roundingAmount: Value(payment.roundingAmount),
                status: const Value('COMPLETED'),
                metadata: Value(metadataJson),
                paidAt: Value(now),
                createdAt: Value(now),
              ),
            );
      }

      // 5. Clean up draft if this transaction was converted from a draft
      if (draftId != null && draftId.isNotEmpty) {
        await _db.transactionDao.deleteTransactionWithItems(draftId);
      }

      // 6. Enqueue COMPLETE_TRANSACTION sync event if in Cloud Mode
      if (_isCloudMode) {
        final syncPayload = {
          'id': transactionId,
          'transactionNumber': transactionNumber,
          'customerId': customerId,
          'promotionId': promotionId,
          'orderType': orderType,
          'queueNumber': queueNumber,
          'subtotal': subtotal,
          'discountType': discountType,
          'discountValue': discountValue,
          'discountTotal': discountTotal,
          'roundingAmount': roundingAmount,
          'total': total,
          'items': items.map((it) => {
            'productId': it.productId,
            'productName': it.productName,
            'variantId': it.variantId,
            'quantity': it.quantity,
            'unitPrice': it.unitPrice,
            'discountType': it.discountType,
            'discountValue': it.discountValue,
            'discountAmount': it.discountAmount,
            'subtotal': it.subtotal,
            'total': it.total,
          }).toList(),
          'payments': payments.map((p) => {
            'paymentMethodId': p.paymentMethodId,
            'amount': p.amount,
            'roundingAmount': p.roundingAmount,
            'paymentType': p.paymentType,
            'tenderedAmount': p.tenderedAmount,
            'changeAmount': p.changeAmount,
            'referenceNumber': p.referenceNumber,
            'note': p.note,
          }).toList(),
        };

        await _db.syncEventDao.insertEvent(
          SyncEventsCompanion.insert(
            id: _uuid.v4(),
            storeId: storeId,
            deviceId: _deviceId ?? 'pos-device',
            entityType: 'Transaction',
            entityId: transactionId,
            operation: 'COMPLETE_TRANSACTION',
            payload: jsonEncode(syncPayload),
            status: 'PENDING',
            createdAt: now,
          ),
        );
      }

      return transactionId;
    });
  }

  @override
  Future<void> cancelTransaction({
    required String transactionId,
    required String reason,
  }) async {
    final now = DateTime.now();

    return _db.transaction(() async {
      final trx = await _db.transactionDao.getTransactionById(transactionId);
      if (trx == null) {
        throw Exception('Transaksi tidak ditemukan');
      }
      if (trx.status != 'COMPLETED') {
        throw Exception('Hanya transaksi selesai (COMPLETED) yang dapat dibatalkan');
      }

      // 1. Mark transaction as CANCELLED
      await (_db.update(_db.transactions)
            ..where((tbl) => tbl.id.equals(transactionId)))
          .write(TransactionsCompanion(
        status: const Value('CANCELLED'),
        cancelledAt: Value(now),
        updatedAt: Value(now),
      ));

      // 2. Perform Stock Reversal for each item
      final items = await _db.transactionDao.getItemsByTransactionId(transactionId);
      for (final item in items) {
        if (item.variantId != null && item.variantId!.isNotEmpty) {
          final variant = await (_db.select(_db.productVariants)
                ..where((tbl) => tbl.id.equals(item.variantId!)))
              .getSingleOrNull();
          if (variant != null) {
            await (_db.update(_db.productVariants)
                  ..where((tbl) => tbl.id.equals(variant.id)))
                .write(ProductVariantsCompanion(
              stock: Value(variant.stock + item.quantity.round()),
              updatedAt: Value(now),
            ));
          }
        }

        final product = await (_db.select(_db.products)
              ..where((tbl) => tbl.id.equals(item.productId)))
            .getSingleOrNull();
        if (product != null) {
          await (_db.update(_db.products)
                ..where((tbl) => tbl.id.equals(product.id)))
              .write(ProductsCompanion(
            stock: Value(product.stock + item.quantity.round()),
            updatedAt: Value(now),
          ));
        }

        // Ledger entry for reversal (signed integer scale 1000)
        await _db.into(_db.stockMovements).insert(
              StockMovementsCompanion(
                id: Value(_uuid.v4()),
                storeId: Value(trx.storeId),
                productId: Value(item.productId),
                variantId: Value(item.variantId),
                type: const Value('CANCEL_REVERSAL'),
                quantityDelta: Value((item.quantity * 1000).round()), // Positive reversal
                unitCost: Value(item.unitCostSnapshot),
                referenceType: const Value('TRANSACTION'),
                referenceId: Value(transactionId),
                reason: Value(reason),
                createdAt: Value(now),
              ),
            );
      }

      // 3. Enqueue CANCEL_TRANSACTION sync event if in Cloud Mode
      if (_isCloudMode) {
        await _db.syncEventDao.insertEvent(
          SyncEventsCompanion.insert(
            id: _uuid.v4(),
            storeId: trx.storeId,
            deviceId: _deviceId ?? 'pos-device',
            entityType: 'Transaction',
            entityId: transactionId,
            operation: 'CANCEL_TRANSACTION',
            payload: jsonEncode({
              'transactionId': transactionId,
              'reason': reason,
            }),
            status: 'PENDING',
            createdAt: now,
          ),
        );
      }
    });
  }

  @override
  Future<String> refundTransaction({
    required String transactionId,
    required String reason,
    required List<RefundItemInput> items,
    required int totalRefundAmount,
  }) async {
    final now = DateTime.now();
    final refundId = _uuid.v4();

    return _db.transaction(() async {
      final trx = await _db.transactionDao.getTransactionById(transactionId);
      if (trx == null) {
        throw Exception('Transaksi tidak ditemukan');
      }

      // 1. Insert Refund Record
      await _db.into(_db.refunds).insert(
            RefundsCompanion(
              id: Value(refundId),
              transactionId: Value(transactionId),
              amount: Value(totalRefundAmount),
              reason: Value(reason),
              status: const Value('COMPLETED'),
              createdAt: Value(now),
            ),
          );

      // 2. Insert Refund Items and reverse stock
      int totalRefundedQty = 0;
      for (final refItem in items) {
        totalRefundedQty += refItem.quantity;

        await _db.into(_db.refundItems).insert(
              RefundItemsCompanion(
                id: Value(_uuid.v4()),
                refundId: Value(refundId),
                transactionItemId: Value(refItem.transactionItemId),
                quantity: Value(refItem.quantity),
                amount: Value(refItem.refundAmount),
                createdAt: Value(now),
              ),
            );

        // Reverse stock for refunded item
        if (refItem.variantId != null && refItem.variantId!.isNotEmpty) {
          final variant = await (_db.select(_db.productVariants)
                ..where((tbl) => tbl.id.equals(refItem.variantId!)))
              .getSingleOrNull();
          if (variant != null) {
            await (_db.update(_db.productVariants)
                  ..where((tbl) => tbl.id.equals(variant.id)))
                .write(ProductVariantsCompanion(
              stock: Value(variant.stock + refItem.quantity),
              updatedAt: Value(now),
            ));
          }
        }

        final product = await (_db.select(_db.products)
              ..where((tbl) => tbl.id.equals(refItem.productId)))
            .getSingleOrNull();
        if (product != null) {
          await (_db.update(_db.products)
                ..where((tbl) => tbl.id.equals(product.id)))
              .write(ProductsCompanion(
            stock: Value(product.stock + refItem.quantity),
            updatedAt: Value(now),
          ));
        }

        // Ledger row for refund reversal
        await _db.into(_db.stockMovements).insert(
              StockMovementsCompanion(
                id: Value(_uuid.v4()),
                storeId: Value(trx.storeId),
                productId: Value(refItem.productId),
                variantId: Value(refItem.variantId),
                type: const Value('REFUND_REVERSAL'),
                quantityDelta: Value(refItem.quantity * 1000),
                referenceType: const Value('REFUND'),
                referenceId: Value(refundId),
                reason: Value(reason),
                createdAt: Value(now),
              ),
            );
      }

      // 3. Update Transaction Status
      final originalItems =
          await _db.transactionDao.getItemsByTransactionId(transactionId);
      final originalTotalQty =
          originalItems.fold<double>(0.0, (sum, i) => sum + i.quantity);

      final newStatus = totalRefundedQty >= originalTotalQty
          ? 'REFUNDED'
          : 'PARTIALLY_REFUNDED';

      await (_db.update(_db.transactions)
            ..where((tbl) => tbl.id.equals(transactionId)))
          .write(TransactionsCompanion(
        status: Value(newStatus),
        refundedAt: Value(now),
        updatedAt: Value(now),
      ));

      // 4. Enqueue REFUND_TRANSACTION sync event if in Cloud Mode
      if (_isCloudMode) {
        await _db.syncEventDao.insertRawEvent(
          id: _uuid.v4(),
          storeId: trx.storeId,
          deviceId: _deviceId ?? 'pos-device',
          entityType: 'Transaction',
          entityId: transactionId,
          operation: 'REFUND_TRANSACTION',
          payload: jsonEncode({
            'id': refundId,
            'transactionId': transactionId,
            'reason': reason,
            'amount': totalRefundAmount,
            'refundedAt': now.toUtc().toIso8601String(),
            'isFullRefund': totalRefundedQty >= originalTotalQty,
            'items': items.map((it) => {
              'transactionItemId': it.transactionItemId,
              'productId': it.productId,
              'variantId': it.variantId,
              'quantity': it.quantity,
              'refundAmount': it.refundAmount,
            }).toList(),
          }),
          status: 'PENDING',
          createdAt: now,
        );
      }

      return refundId;
    });
  }

  @override
  Stream<List<Transaction>> watchTransactions(String storeId, {int limit = 50}) {
    return _db.transactionDao.watchTransactionsByStore(storeId, limit: limit);
  }

  @override
  Future<void> createTransaction({
    required TransactionsCompanion transaction,
    required List<TransactionItemsCompanion> items,
    PaymentsCompanion? payment,
  }) async {
    await _db.transactionDao.saveTransactionWithItems(
      transaction: transaction,
      items: items,
    );
    if (payment != null) {
      await _db.paymentDao.insertPayment(payment);
    }
  }

  @override
  Future<Transaction?> getTransaction(String id) =>
      _db.transactionDao.getTransactionById(id);

  @override
  Future<List<TransactionItem>> getTransactionItems(String transactionId) =>
      _db.transactionDao.getItemsByTransactionId(transactionId);

  @override
  Future<List<Payment>> getTransactionPayments(String transactionId) =>
      _db.paymentDao.getPaymentsByTransactionId(transactionId);

  @override
  Future<List<Refund>> getTransactionRefunds(String transactionId) {
    return (_db.select(_db.refunds)
          ..where((tbl) => tbl.transactionId.equals(transactionId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .get();
  }

  @override
  Future<List<RefundItem>> getRefundItems(String refundId) {
    return (_db.select(_db.refundItems)
          ..where((tbl) => tbl.refundId.equals(refundId)))
        .get();
  }

  String _generateTransactionNumber(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}${date.minute.toString().padLeft(2, '0')}${date.second.toString().padLeft(2, '0')}';
    final suffix = _uuid.v4().replaceAll('-', '').substring(0, 8).toUpperCase();
    return 'TRX-$year$month$day-$timeStr-$suffix';
  }
}
