import 'package:flutter/material.dart';

import '../../core/theme/clivora_colors.dart';

class CoachMarkStep {
  const CoachMarkStep({
    required this.targetKey,
    required this.title,
    required this.body,
    this.padding = const EdgeInsets.all(4),
  });

  final GlobalKey targetKey;
  final String title;
  final String body;
  final EdgeInsets padding;
}

/// Spotlight coach marks, scrolls target into view and re-measures on layout/scroll.
class CoachMarkOverlay extends StatefulWidget {
  const CoachMarkOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
    required this.child,
    this.scrollController,
    this.nextLabel = 'Next',
    this.doneLabel = 'Got it',
    this.skipLabel = 'Skip tour',
    this.bottomInset = 96,
    this.onSkip,
  });

  final List<CoachMarkStep> steps;
  final VoidCallback onComplete;
  final VoidCallback? onSkip;
  final Widget child;
  final ScrollController? scrollController;
  final String nextLabel;
  final String doneLabel;
  final String skipLabel;
  final double bottomInset;

  static double shellBottomInset(BuildContext context) {
    return MediaQuery.paddingOf(context).bottom + 96;
  }

  @override
  State<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<CoachMarkOverlay> {
  int _index = 0;
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareStep());
  }

  @override
  void didUpdateWidget(CoachMarkOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_onScroll);
      widget.scrollController?.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() => _measure();

  Future<void> _prepareStep() async {
    if (_index >= widget.steps.length) return;
    final ctx = widget.steps[_index].targetKey.currentContext;
    if (ctx != null) {
      try {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: 0.15,
        );
      } catch (_) {}
    }
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    _measure();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (mounted) _measure();
  }

  void _measure() {
    if (_index >= widget.steps.length) return;
    final step = widget.steps[_index];
    final ctx = step.targetKey.currentContext;
    if (ctx == null) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _measure();
      });
      return;
    }

    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _measure();
      });
      return;
    }

    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    final pad = step.padding;
    final rect = Rect.fromLTWH(
      offset.dx - pad.left,
      offset.dy - pad.top,
      size.width + pad.horizontal,
      size.height + pad.vertical,
    );

    if (!mounted) return;
    setState(() => _targetRect = rect);
  }

  void _next() {
    if (_index < widget.steps.length - 1) {
      setState(() {
        _index++;
        _targetRect = null;
      });
      _prepareStep();
    } else {
      widget.onComplete();
    }
  }

  void _skip() {
    if (widget.onSkip != null) {
      widget.onSkip!();
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxBottom = MediaQuery.sizeOf(context).height -
        (widget.bottomInset > 0 ? widget.bottomInset : CoachMarkOverlay.shellBottomInset(context));

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_targetRect != null) ...[
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _SpotlightPainter(hole: _targetRect!),
              ),
            ),
          ),
          _TooltipCard(
            rect: _targetRect!,
            maxBottom: maxBottom,
            stepIndex: _index,
            stepCount: widget.steps.length,
            title: widget.steps[_index].title,
            body: widget.steps[_index].body,
            actionLabel: _index == widget.steps.length - 1 ? widget.doneLabel : widget.nextLabel,
            skipLabel: widget.skipLabel,
            onAction: _next,
            onSkip: _skip,
          ),
        ],
      ],
    );
  }
}

class _TooltipCard extends StatelessWidget {
  const _TooltipCard({
    required this.rect,
    required this.maxBottom,
    required this.stepIndex,
    required this.stepCount,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.skipLabel,
    required this.onAction,
    required this.onSkip,
  });

  final Rect rect;
  final double maxBottom;
  final int stepIndex;
  final int stepCount;
  final String title;
  final String body;
  final String actionLabel;
  final String skipLabel;
  final VoidCallback onAction;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    const cardHeight = 200.0;
    final spaceBelow = maxBottom - rect.bottom;
    final spaceAbove = rect.top - 72;
    final preferBelow = spaceBelow >= cardHeight + 20;
    final preferAbove = spaceAbove >= cardHeight + 20;

    double top;
    if (preferBelow) {
      top = rect.bottom + 14;
    } else if (preferAbove) {
      top = rect.top - cardHeight - 14;
    } else if (spaceBelow >= spaceAbove) {
      top = (rect.bottom + 10).clamp(72.0, maxBottom - cardHeight);
    } else {
      top = (rect.top - cardHeight - 10).clamp(72.0, maxBottom - cardHeight);
    }

    return Positioned(
      left: 20,
      right: 20,
      top: top,
      child: Material(
        elevation: 14,
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).cardColor,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${stepIndex + 1} of $stepCount',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: ClivoraColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ClivoraColors.textSecondary)),
              const SizedBox(height: 14),
              Row(
                children: [
                  TextButton(onPressed: onSkip, child: Text(skipLabel)),
                  const Spacer(),
                  FilledButton(onPressed: onAction, child: Text(actionLabel)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.hole});

  final Rect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(14)));
    final combined = Path.combine(PathOperation.difference, path, holePath);
    canvas.drawPath(combined, Paint()..color = Colors.black.withValues(alpha: 0.65));
    canvas.drawRRect(
      RRect.fromRectAndRadius(hole, const Radius.circular(14)),
      Paint()
        ..color = ClivoraColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) => old.hole != hole;
}
