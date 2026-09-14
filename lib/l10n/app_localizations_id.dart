// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'UMKM POS';

  @override
  String get dashboard => 'Dasbor';

  @override
  String get cashier => 'Kasir POS';

  @override
  String get products => 'Produk';

  @override
  String get inventory => 'Inventori';

  @override
  String get transactions => 'Transaksi';

  @override
  String get reports => 'Laporan';

  @override
  String get settings => 'Pengaturan';

  @override
  String get cashRounding => 'Pembulatan Tunai';

  @override
  String get cashRoundingDesc =>
      'Membulatkan total pembayaran tunai ke pecahan rupiah terdekat';

  @override
  String get roundNearest => 'Bulatkan Terdekat (Half-Up)';

  @override
  String get roundDown => 'Bulatkan ke Bawah (Floor)';

  @override
  String get roundUp => 'Bulatkan ke Atas (Ceil)';

  @override
  String get roundingIncrement => 'Pecahan Pembulatan';

  @override
  String get originalAmount => 'Jumlah Awal';

  @override
  String get roundedAmount => 'Jumlah Dibulatkan';

  @override
  String get roundingDifference => 'Selisih Pembulatan';

  @override
  String get systemStatus => 'Status Sistem';

  @override
  String get readyForUse => 'Siap Digunakan';

  @override
  String get phase0Complete => 'Fondasi Phase 0 Aktif';
}
