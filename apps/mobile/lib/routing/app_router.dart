import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_route_helper.dart';
import '../core/services/onboarding_service.dart';
import '../core/auth/auth_session.dart';
import '../features/client/client_contracts_screen.dart';
import '../features/client/client_invoices_screen.dart';
import '../features/client/client_link_freelancer_screen.dart';
import '../features/messages/simple_chat_screen.dart';
import '../features/client/client_portal_screen.dart';
import '../features/client/client_activity_screen.dart';
import '../features/client/client_tasks_screen.dart';
import '../features/client/client_account_screen.dart';
import '../features/client/client_hub_screen.dart';
import '../features/client/client_quotes_screen.dart';
import '../features/client/client_payments_screen.dart';
import '../features/client/client_credits_screen.dart';
import '../features/client/client_recurring_screen.dart';
import '../features/client/client_files_screen.dart';
import '../features/team/team_screen.dart';
import '../features/team/team_invites_screen.dart';
import '../features/customers/customer_form_screen.dart';
import '../features/customers/customers_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/expenses/expenses_screen.dart';
import '../features/invoices/invoice_form_screen.dart';
import '../features/invoices/invoices_screen.dart';
import '../features/more/more_screen.dart';
import '../features/more/menu_screen.dart';
import '../features/notes/notes_screen.dart';
import '../features/projects/project_time_tracker_screen.dart';
import '../features/projects/project_milestones_screen.dart';
import '../features/projects/project_form_screen.dart';
import '../features/projects/projects_screen.dart';
import '../features/reviews/reviews_screen.dart';
import '../features/analytics/analytics_dashboard_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/settings/backup_restore_screen.dart';
import '../features/marketplace/connect_marketplace_screen.dart';
import '../features/marketplace/connect_listing_screen.dart';
import '../features/marketplace/connect_need_screen.dart';
import '../features/settings/legal_document_screen.dart';
import '../features/settings/notification_settings_screen.dart';
import '../features/settings/security_settings_screen.dart';
import '../features/sync/sync_center_screen.dart';
import '../features/invoices/payment_confirmations_screen.dart';
import '../features/client/client_milestones_screen.dart';
import '../core/constants/legal_documents.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/value_guidelines_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/search/global_search_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/auth/auth_screens.dart';
import '../features/profile/profile_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/automation/automation_builder_screen.dart';
import '../features/tools/tools_screens.dart';
import '../features/edition/edition_screen.dart';
import '../features/tasks/tasks_screen.dart';
import '../features/tasks/workspace_tasks_screen.dart';
import '../features/sync/crm_conflicts_screen.dart';
import '../features/products/products_screen.dart';
import '../features/quotes/quotes_screen.dart';
import '../features/invoices/recurring_invoices_screen.dart';
import '../features/credits/credits_screen.dart';
import 'app_shell.dart';
import 'auth_refresh.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  refreshListenable: authRefreshListenable,
  redirect: (context, state) => authRedirect(
    location: state.matchedLocation,
    user: authSessionUser,
    loading: authSessionLoading,
  ),
  routes: [
    GoRoute(
      path: '/value-guidelines',
      builder: (context, state) => Consumer(
        builder: (context, ref, _) => ValueGuidelinesScreen(
          onContinue: () async {
            await ref.read(onboardingServiceProvider).markGuidelinesSeen();
            if (context.mounted) {
              final done = await ref.read(onboardingServiceProvider).isComplete();
              if (!context.mounted) return;
              context.go(done ? '/login' : '/onboarding');
            }
          },
        ),
      ),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => Consumer(
        builder: (context, ref, _) => OnboardingScreen(
          onComplete: () async {
            await ref.read(onboardingServiceProvider).markComplete();
            if (context.mounted) context.go('/login');
          },
        ),
      ),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: DashboardScreen()),
        ),
        GoRoute(
          path: '/customers',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: CustomersScreen()),
        ),
        GoRoute(
          path: '/projects',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProjectsScreen()),
        ),
        GoRoute(
          path: '/invoices',
          pageBuilder: (context, state) {
            final filter = state.uri.queryParameters['filter'];
            return NoTransitionPage(child: InvoicesScreen(initialFilter: filter));
          },
        ),
        GoRoute(
          path: '/client-messages',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SimpleChatScreen(isClient: true)),
        ),
        GoRoute(
          path: '/client-link-freelancer',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ClientLinkFreelancerScreen()),
        ),
        GoRoute(
          path: '/client-invoices',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ClientInvoicesScreen()),
        ),
        GoRoute(
          path: '/client-portal',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ClientPortalScreen()),
        ),
        GoRoute(
          path: '/client-activity',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ClientActivityScreen()),
        ),
        GoRoute(
          path: '/client-contracts',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ClientContractsScreen()),
        ),
        GoRoute(
          path: '/client-tasks',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ClientTasksScreen()),
        ),
        GoRoute(
          path: '/client-account',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ClientAccountScreen()),
        ),
        GoRoute(
          path: '/freelancer-messages',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SimpleChatScreen(isClient: false)),
        ),
        GoRoute(
          path: '/more',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: MoreScreen()),
        ),
        GoRoute(
          path: '/menu',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: MenuScreen()),
        ),
        GoRoute(
          path: '/connect',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ConnectMarketplaceScreen()),
        ),
        GoRoute(
          path: '/client-hub',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ClientHubScreen()),
        ),
        GoRoute(
          path: '/client-quotes',
          builder: (context, state) => const ClientQuotesScreen(),
        ),
        GoRoute(
          path: '/client-payments',
          builder: (context, state) => const ClientPaymentsScreen(),
        ),
        GoRoute(
          path: '/client-credits',
          builder: (context, state) => const ClientCreditsScreen(),
        ),
        GoRoute(
          path: '/client-recurring',
          builder: (context, state) => const ClientRecurringScreen(),
        ),
        GoRoute(
          path: '/client-files',
          builder: (context, state) => const ClientFilesScreen(),
        ),
        GoRoute(
          path: '/products',
          builder: (context, state) => const ProductsScreen(),
        ),
      ],
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/customers/new',
      builder: (context, state) => const CustomerFormScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/customers/:id/edit',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return CustomerFormScreen(customerId: id);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/projects/new',
      builder: (context, state) => const ProjectFormScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/projects/:id/edit',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return ProjectFormScreen(projectId: id);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/projects/:id/time',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return ProjectTimeTrackerScreen(projectId: id);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/projects/:id/milestones',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return ProjectMilestonesScreen(projectId: id);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/reviews',
      builder: (context, state) => const ReviewsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/invoices/new',
      builder: (context, state) => const InvoiceFormScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/invoices/:id/edit',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return InvoiceFormScreen(invoiceId: id);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/tasks',
      builder: (context, state) => const TasksScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/tasks/new',
      builder: (context, state) => const TaskFormScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/tasks/:id/edit',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return TaskFormScreen(taskId: id);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/expenses',
      builder: (context, state) => const ExpensesScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/expenses/new',
      builder: (context, state) => const ExpenseFormScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/expenses/:id/edit',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return ExpenseFormScreen(expenseId: id);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/notes',
      builder: (context, state) => const NotesScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/notes/new',
      builder: (context, state) => const NoteFormScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/notes/:id/edit',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return NoteFormScreen(noteId: id);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/search',
      builder: (context, state) => const GlobalSearchScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/reports',
      builder: (context, state) => const ReportsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/calendar',
      builder: (context, state) => const CalendarScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/workspace-tasks',
      builder: (context, state) => const WorkspaceTasksScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/campaigns',
      builder: (context, state) => const EditionScreen(feature: 'Campaigns'),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/automation-builder',
      builder: (context, state) => const AutomationBuilderScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/ai-suggestions',
      builder: (context, state) => const EditionScreen(feature: 'AI suggestions'),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/crm-conflicts',
      builder: (context, state) => const CrmConflictsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/admin-ops',
      builder: (context, state) => const EditionScreen(feature: 'Admin operations'),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/payments',
      builder: (context, state) => const PaymentsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/team',
      builder: (context, state) => const TeamScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/team-invites',
      builder: (context, state) => const TeamInvitesScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/upgrade',
      builder: (context, state) => const EditionScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/referral',
      builder: (context, state) => const EditionScreen(feature: 'Referral rewards'),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/ai-assistant',
      builder: (context, state) => const EditionScreen(feature: 'CLIVORA AI'),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/templates',
      builder: (context, state) => const MessageTemplatesScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/contracts',
      builder: (context, state) => const ContractsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/automations',
      builder: (context, state) => const AutomationsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/analytics',
      builder: (context, state) => const AnalyticsDashboardScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/backup',
      builder: (context, state) => const BackupRestoreScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/connect/listing',
      builder: (context, state) => const ConnectListingScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/connect/need',
      builder: (context, state) => const ConnectNeedScreen(),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/quotes',
      builder: (context, state) => const QuotesScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/recurring-invoices',
      builder: (context, state) => const RecurringInvoicesScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/vendors',
      redirect: (_, _) => '/more',
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/purchase-orders',
      redirect: (_, _) => '/more',
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/credits',
      builder: (context, state) => const CreditsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/security',
      builder: (context, state) => const SecuritySettingsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/sync-center',
      builder: (context, state) => const SyncCenterScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/notification-settings',
      builder: (context, state) => const NotificationSettingsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/payment-confirmations',
      builder: (context, state) => const PaymentConfirmationsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/client-milestones',
      builder: (context, state) => const ClientMilestonesScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/licenses',
      redirect: (_, _) => '/privacy',
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/privacy',
      builder: (context, state) => const LegalDocumentScreen(
        title: LegalDocuments.privacyTitle,
        updated: LegalDocuments.privacyUpdated,
        body: LegalDocuments.privacyBody,
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/terms',
      builder: (context, state) => const LegalDocumentScreen(
        title: LegalDocuments.termsTitle,
        updated: LegalDocuments.termsUpdated,
        body: LegalDocuments.termsBody,
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/admin-console',
      builder: (context, state) => const EditionScreen(feature: 'Admin console'),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/admin',
      builder: (context, state) => const EditionScreen(feature: 'Admin dashboard'),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/storage',
      builder: (context, state) => const StorageScreen(),
    ),
  ],
);
