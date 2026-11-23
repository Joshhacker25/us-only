import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Floating-hearts burst. Respects reduced motion: when
/// `MediaQuery.disableAnimations` is true, no hearts animate and the child
/// is shown unchanged.
class HeartBurstAnimation extends StatefulWidget {
  const HeartBurstAnimation({
    super.key,
    required this.child,
    this.onBurst,
  });

  final Widget child;
  final VoidCallback? onBurst;

  @override
  State<HeartBurstAnimation> createState() => _HeartBurstAnimationState();
}

class _HeartBurstAnimationState extends State<HeartBurstAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final math.Random _random = math.Random();
  late final List<_HeartSpec> _hearts;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _hearts = List<_HeartSpec>.generate(10, (int i) {
      return _HeartSpec(
        dx: (_random.nextDouble() - 0.5) * 120,
        size: 14 + _random.nextDouble() * 14,
        delay: _random.nextDouble() * 0.3,
        color: i.isEven ? AppColors.pink : AppColors.purpleLight,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _burst() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    _controller.forward(from: 0);
    widget.onBurst?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return GestureDetector(onTap: widget.onBurst, child: widget.child);
    }
    return GestureDetector(
      onTap: _burst,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          widget.child,
          AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              return Stack(
                clipBehavior: Clip.none,
                children: _hearts.map(( _HeartSpec spec) {
                  final double t = (_controller.value - spec.delay)
                      .clamp(0.0, 1.0);
                  return Positioned(
                    left: spec.dx * t,
                    top: -70 * t,
                    child: Opacity(
                      opacity: 1 - t,
                      child: Icon(
                        Icons.favorite,
                        color: spec.color,
                        size: spec.size * (1 - t * 0.3),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeartSpec {
  const _HeartSpec({
    required this.dx,
    required this.size,
    required this.delay,
    required this.color,
  });

  final double dx;
  final double size;
  final double delay;
  final Color color;
}
