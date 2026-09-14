// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'UMKM POS';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get cashier => 'POS Cashier';

  @override
  String get products => 'Products';

  @override
  String get inventory => 'Inventory';

  @override
  String get transactions => 'Transactions';

  @override
  String get reports => 'Reports';

  @override
  String get settings => 'Settings';

  @override
  String get cashRounding => 'Cash Rounding';

  @override
  String get cashRoundingDesc =>
      'Rounding cash payment total to nearest denomination';

  @override
  String get roundNearest => 'Round to Nearest (Half-Up)';

  @override
  String get roundDown => 'Round Down (Floor)';

  @override
  String get roundUp => 'Round Up (Ceil)';

  @override
  String get roundingIncrement => 'Rounding Increment';

  @override
  String get originalAmount => 'Original Amount';

  @override
  String get roundedAmount => 'Rounded Amount';

  @override
  String get roundingDifference => 'Rounding Difference';

  @override
  String get systemStatus => 'System Status';

  @override
  String get readyForUse => 'Ready for Use';

  @override
  String get phase0Complete => 'Phase 0 Foundation Active';
}
