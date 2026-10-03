import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/review_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/empty_state.dart';

class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(ownerReviewsProvider);
    final scheme = Theme.of(context).colorScheme;

    return ClivoraScaffold(
      title: 'Client reviews',
      showBackButton: true,
      body: reviewsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (reviews) {
          if (reviews.isEmpty) {
            return const EmptyState(
              icon: Icons.star_outline,
              message: 'No reviews yet. When clients finish a project, they can leave star ratings here.',
            );
          }
          final avg = reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Text(avg.toStringAsFixed(1), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: ClivoraColors.primary)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: List.generate(5, (i) => Icon(i < avg.round() ? Icons.star : Icons.star_border, color: ClivoraColors.accent, size: 20)),
                            ),
                            Text('${reviews.length} review${reviews.length == 1 ? '' : 's'}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...reviews.map(
                (r) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Row(
                      children: [
                        ...List.generate(5, (i) => Icon(i < r.rating ? Icons.star : Icons.star_border, size: 16, color: ClivoraColors.accent)),
                        const SizedBox(width: 8),
                        Text('${r.rating}/5', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        r.comment.isEmpty ? 'No written feedback' : r.comment,
                        style: TextStyle(color: scheme.onSurface),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
