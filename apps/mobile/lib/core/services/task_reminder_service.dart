import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/app_providers.dart';
import '../auth/auth_service.dart';
import 'local_notification_service.dart';

final taskReminderServiceProvider = Provider<TaskReminderService>((ref) {
  return TaskReminderService(ref);
});

/// Schedules local notifications for tasks with due dates.
class TaskReminderService {
  TaskReminderService(this.ref);

  final Ref ref;
  bool _tzReady = false;

  Future<void> _ensureTz() async {
    if (_tzReady) return;
    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
    _tzReady = true;
  }

  Future<void> syncAllForCurrentUser() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    await _ensureTz();
    final db = ref.read(databaseProvider);
    final tasks = await db.watchTasksForUser(user.id).first;
    for (final task in tasks.where((t) => !t.completed && t.dueDate != null)) {
      await scheduleForTask(task);
    }
  }

  Future<void> scheduleForTask(Task task) async {
    if (task.dueDate == null || task.completed) return;
    await _ensureTz();
    final when = DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day, 9);
    if (when.isBefore(DateTime.now())) return;

    final local = tz.TZDateTime.from(when, tz.local);
    await ref.read(localNotificationServiceProvider).scheduleAt(
          id: task.id,
          title: 'Task due',
          body: '${task.title} is due today',
          when: local,
          payload: 'task:${task.id}',
        );
  }

  Future<void> cancelForTask(int taskId) async {
    await ref.read(localNotificationServiceProvider).cancel(taskId);
  }
}
