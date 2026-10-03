import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_service.dart';
import '../auth/user_roles.dart';
import '../constants/plan_features.dart';
import '../constants/plan_limits.dart';
import '../services/email_verification_service.dart';
import 'plan_limit_dialog.dart';
import '../../data/providers/app_providers.dart';

/// Opens create/edit screens (limits should be checked before calling).
void openFormRoute(BuildContext context, String path) {
  context.push(path);
}

/// Opens notifications for freelancer and client accounts.
void openNotifications(BuildContext context, {required bool isClient}) {
  context.push('/notifications');
}

/// Shows upgrade dialog, works for both freelancer and client accounts.
Future<bool> requireProFeature(
  BuildContext context, {
  required bool isPro,
  required String featureName,
  bool isClient = false,
}) async {
  if (isPro) return true;
  final planName = isClient ? 'Client Pro' : 'Freelancer Pro';
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('$featureName ($planName)'),
      content: Text(
        '$featureName requires $planName (\$9/mo, limited offer from \$14). '
        'Subscribe securely through Google Play.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('View plans')),
      ],
    ),
  );
  if (result == true && context.mounted) {
    context.push('/upgrade');
  }
  return false;
}

Future<bool> guardAccountFeature(
  BuildContext context,
  WidgetRef ref, {
  required String feature,
  required String featureName,
}) async {
  final user = ref.read(authStateProvider).valueOrNull;
  final isClient = isClientUser(user);
  final plan = ref.read(subscriptionPlanProvider).valueOrNull;
  final isPro = ref.read(isProProvider);
  if (PlanFeatures.hasFeature(plan: plan, isClient: isClient, feature: feature)) {
    return true;
  }
  return requireProFeature(context, isPro: isPro, featureName: featureName, isClient: isClient);
}

Future<bool> tryOpenWithPlanCheck(
  BuildContext context, {
  required WidgetRef ref,
  required Future<bool> Function() canAdd,
  required String path,
  required String resource,
  required int max,
}) async {
  if (!await requireEmailVerified(context, ref, actionLabel: 'add $resource')) {
    return false;
  }
  if (!await canAdd()) {
    if (!context.mounted) return false;
    // Distinguish email gate vs plan limit (canAdd already false for unverified).
    final user = ref.read(authStateProvider).valueOrNull;
    if (!ref.read(emailVerificationServiceProvider).isVerified(user)) {
      return false;
    }
    final upgrade = await showPlanLimitDialog(context, resource: resource, max: max);
    if (upgrade && context.mounted) context.push('/upgrade');
    return false;
  }
  if (!context.mounted) return false;
  openFormRoute(context, path);
  return true;
}

/// Opens create routes from AI insights with the same plan checks as list screens.
Future<void> openInsightRoute(BuildContext context, WidgetRef ref, String path) async {
  if (path == '/customers/new') {
    await tryOpenWithPlanCheck(
      context,
      ref: ref,
      canAdd: () => ref.read(planLimitServiceProvider).canAddCustomer(),
      path: path,
      resource: 'clients',
      max: PlanLimits.freeMaxClients,
    );
    return;
  }
  if (path == '/projects/new') {
    await tryOpenWithPlanCheck(
      context,
      ref: ref,
      canAdd: () => ref.read(planLimitServiceProvider).canAddProject(),
      path: path,
      resource: 'projects',
      max: PlanLimits.freeMaxProjects,
    );
    return;
  }
  if (path == '/invoices/new') {
    await tryOpenWithPlanCheck(
      context,
      ref: ref,
      canAdd: () => ref.read(planLimitServiceProvider).canAddInvoice(),
      path: path,
      resource: 'invoices this month',
      max: PlanLimits.freeMaxInvoicesPerMonth,
    );
    return;
  }
  context.push(path);
}
