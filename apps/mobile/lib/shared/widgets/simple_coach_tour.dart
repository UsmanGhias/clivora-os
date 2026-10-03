import 'package:flutter/material.dart';

import '../../core/theme/clivora_colors.dart';

class SimpleCoachStep {
  const SimpleCoachStep({required this.title, required this.body, required this.icon});

  final String title;
  final String body;
  final IconData icon;
}

/// Text-only coach tour (no spotlight) so layout never misaligns on small screens.
Future<void> showSimpleCoachTour(
  BuildContext context, {
  required List<SimpleCoachStep> steps,
  VoidCallback? onComplete,
}) async {
  if (steps.isEmpty) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _SimpleCoachTourDialog(steps: steps, onComplete: onComplete),
  );
}

class _SimpleCoachTourDialog extends StatefulWidget {
  const _SimpleCoachTourDialog({required this.steps, this.onComplete});

  final List<SimpleCoachStep> steps;
  final VoidCallback? onComplete;

  @override
  State<_SimpleCoachTourDialog> createState() => _SimpleCoachTourDialogState();
}

class _SimpleCoachTourDialogState extends State<_SimpleCoachTourDialog> {
  final _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finish() {
    Navigator.of(context).pop();
    widget.onComplete?.call();
  }

  void _next() {
    if (_index < widget.steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 200,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.steps.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final step = widget.steps[i];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(step.icon, size: 44, color: ClivoraColors.primary),
                      const SizedBox(height: 12),
                      Text(
                        '${i + 1} of ${widget.steps.length}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: ClivoraColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        step.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        step.body,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: ClivoraColors.textSecondary,
                            ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Row(
              children: [
                TextButton(onPressed: _finish, child: const Text('Skip tour')),
                const Spacer(),
                FilledButton(
                  onPressed: _next,
                  child: Text(_index == widget.steps.length - 1 ? 'Got it' : 'Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
