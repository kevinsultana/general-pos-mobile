import 'package:go_router/go_router.dart';
import '../../presentation/mode_select/screens/mode_selection_screen.dart';
import '../../presentation/mode_select/screens/local_register_screen.dart';
import '../../presentation/home/home_screen.dart';
import '../../presentation/products/screens/product_list_screen.dart';
import '../../presentation/products/screens/product_form_screen.dart';
import '../../presentation/pos/screens/pos_screen.dart';
import '../../presentation/transactions/screens/transaction_history_screen.dart';
import '../../presentation/customers/screens/customer_list_screen.dart';
import '../../presentation/promotions/screens/promotion_list_screen.dart';
import '../../presentation/settings/screens/store_settings_screen.dart';
import '../../presentation/reports/screens/report_hub_screen.dart';
import '../../presentation/settings/screens/backup_restore_screen.dart';
import '../../presentation/settings/screens/printer_settings_screen.dart';
import '../../presentation/settings/screens/cloud_login_page.dart';
import '../../presentation/settings/screens/cloud_sync_page.dart';
import '../../presentation/settings/screens/order_type_settings_screen.dart';
import '../../presentation/settings/screens/cash_rounding_settings_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/mode-select',
  routes: [
    GoRoute(
      path: '/mode-select',
      builder: (context, state) => const ModeSelectionScreen(),
    ),
    GoRoute(
      path: '/local-register',
      builder: (context, state) => const LocalRegisterScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/pos',
      builder: (context, state) => const PosScreen(),
    ),
    GoRoute(
      path: '/transactions',
      builder: (context, state) => const TransactionHistoryScreen(),
    ),
    GoRoute(
      path: '/customers',
      builder: (context, state) => const CustomerListScreen(),
    ),
    GoRoute(
      path: '/promotions',
      builder: (context, state) => const PromotionListScreen(),
    ),
    GoRoute(
      path: '/reports',
      builder: (context, state) => const ReportHubScreen(),
    ),
    GoRoute(
      path: '/backup',
      builder: (context, state) => const BackupRestoreScreen(),
    ),
    GoRoute(
      path: '/printers',
      builder: (context, state) => const PrinterSettingsScreen(),
    ),
    GoRoute(
      path: '/cloud-login',
      builder: (context, state) => const CloudLoginPage(),
    ),
    GoRoute(
      path: '/cloud-sync',
      builder: (context, state) => const CloudSyncPage(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const StoreSettingsScreen(),
    ),
    GoRoute(
      path: '/order-types',
      builder: (context, state) => const OrderTypeSettingsScreen(),
    ),
    GoRoute(
      path: '/cash-rounding',
      builder: (context, state) => const CashRoundingSettingsScreen(),
    ),
    GoRoute(
      path: '/products',
      builder: (context, state) => const ProductListScreen(),
      routes: [
        GoRoute(
          path: 'new',
          builder: (context, state) => const ProductFormScreen(),
        ),
      ],
    ),
  ],
);
