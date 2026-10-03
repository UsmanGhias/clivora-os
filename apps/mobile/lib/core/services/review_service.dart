import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';
import '../../data/providers/app_providers.dart';
import '../../data/providers/database_provider.dart';
import '../auth/auth_service.dart';
import '../cloud/cloud_notification_repository.dart';
import '../cloud/supabase_sync_service.dart';

final reviewServiceProvider = Provider<ReviewService>((ref) => ReviewService(ref));

class ReviewService {
  ReviewService(this.ref);
  final Ref ref;

  Future<String?> submitClientReview({
    required int projectId,
    required int ownerUserId,
    required int rating,
    required String comment,
    int? customerId,
    String clientEmail = '',
  }) async {
    if (rating < 1 || rating > 5) return 'Rating must be 1-5 stars.';
    final db = ref.read(databaseProvider);
    final existing = await (db.select(db.projectReviews)
          ..where((t) => t.projectId.equals(projectId) & t.fromClient.equals(true)))
        .get();
    if (existing.isNotEmpty) return 'You already reviewed this project.';

    await db.into(db.projectReviews).insert(
          ProjectReviewsCompanion.insert(
            ownerUserId: ownerUserId,
            projectId: projectId,
            customerId: Value(customerId),
            clientEmail: Value(clientEmail.trim().toLowerCase()),
            rating: Value(rating),
            comment: Value(comment.trim()),
            fromClient: const Value(true),
          ),
        );

    final toUid = await ref.read(supabaseSyncServiceProvider).uidForEmail(
          (await db.getUser(ownerUserId))?.email ?? '',
        );
    if (toUid != null) {
      await ref.read(cloudNotificationRepositoryProvider).sendToUid(
            toUid: toUid,
            title: 'New $rating★ project review',
            body: comment.trim().isEmpty ? 'A client left feedback on your project.' : comment.trim(),
            kind: 'review',
          );
    }
    return null;
  }

  Future<double> averageRatingForOwner(int ownerUserId) async {
    final rows = await ref.read(databaseProvider).watchReviewsForOwner(ownerUserId).first;
    if (rows.isEmpty) return 0;
    return rows.map((r) => r.rating).reduce((a, b) => a + b) / rows.length;
  }
}

final ownerReviewsProvider = StreamProvider<List<ProjectReview>>((ref) {
  final ownerId = ref.watch(authStateProvider).valueOrNull?.id;
  if (ownerId == null) return const Stream.empty();
  return ref.watch(databaseProvider).watchReviewsForOwner(ownerId);
});
