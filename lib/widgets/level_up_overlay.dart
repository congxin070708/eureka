import 'dart:math';
import 'package:flutter/material.dart';
import '../app_theme.dart';

/// 升级全屏特效
///
/// 灵感来自游戏升级动画：
/// - 全屏粒子爆发
/// - 等级数字跳动
/// - 解锁提示
/// - 震动 + 光效
class LevelUpOverlay extends StatefulWidget {
  final int oldLevel;
  final int newLevel;
  final int xpGained;
  final List<String> unlocks; // 解锁的内容
  final VoidCallback onDismiss;

  const LevelUpOverlay({
    super.key,
    required this.oldLevel,
    required this.newLevel,
    required this.xpGained,
    required this.unlocks,
    required this.onDismiss,
  });

  @override
  State<LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<LevelUpOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _particleAnim;
  int _displayLevel = 0;

  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.95), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.05), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.2, curve: Curves.easeOut),
      ),
    );

    _particleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );

    // 生成粒子
    final rng = Random();
    for (int i = 0; i < 40; i++) {
      _particles.add(_Particle(
        angle: rng.nextDouble() * 2 * pi,
        speed: 0.3 + rng.nextDouble() * 0.7,
        size: 3 + rng.nextDouble() * 8,
        color: _particleColors[rng.nextInt(_particleColors.length)],
        delay: rng.nextDouble() * 0.3,
      ));
    }

    _ctrl.forward();

    // 数字跳动
    _animateNumber();
  }

  static const List<Color> _particleColors = [
    Color(0xFFf59e0b),
    Color(0xFFf97316),
    Color(0xFFef4444),
    Color(0xFFa855f7),
    Color(0xFF3b82f6),
    Color(0xFF22c55e),
    Colors.white,
  ];

  void _animateNumber() async {
    final duration = const Duration(milliseconds: 1200);
    final steps = 30;
    final stepDuration = duration ~/ steps;
    final totalGain = widget.newLevel - widget.oldLevel;

    for (int i = 0; i <= steps; i++) {
      await Future.delayed(stepDuration);
      if (!mounted) return;
      final progress = i / steps;
      final eased = 1 - pow(1 - progress, 3); // easeOutCubic
      setState(() {
        _displayLevel = (widget.oldLevel + totalGain * eased).round();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: _dismiss,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Container(
            color: Colors.black.withValues(alpha: _fadeAnim.value * 0.7),
            child: Stack(
              children: [
                // 粒子层
                if (_particleAnim.value > 0)
                  CustomPaint(
                    size: Size.infinite,
                    painter: _ParticlePainter(
                      particles: _particles,
                      progress: _particleAnim.value,
                    ),
                  ),
                // 光环
                Center(
                  child: Container(
                    width: 300 * _scaleAnim.value,
                    height: 300 * _scaleAnim.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFf59e0b).withValues(alpha: 0.6),
                          const Color(0xFFf97316).withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                // 主内容
                Center(
                  child: Transform.scale(
                    scale: _scaleAnim.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'LEVEL UP!',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 4,
                            shadows: [
                              Shadow(
                                color: const Color(0xFFf59e0b).withValues(alpha: 0.8),
                                blurRadius: 20,
                              ),
                              const Shadow(
                                color: Color(0xFFf97316),
                                blurRadius: 40,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // 大等级数字
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFfef3c7), Color(0xFFf59e0b)],
                            ),
                            border: Border.all(
                              color: Colors.white,
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFf59e0b).withValues(alpha: 0.6),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '$_displayLevel',
                              style: const TextStyle(
                                fontSize: 72,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF7c2d12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '获得 +${widget.xpGained} 经验',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFfde68a),
                          ),
                        ),
                        if (widget.unlocks.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            margin: const EdgeInsets.symmetric(horizontal: 40),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  '🎉 解锁新内容',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white),
                                ),
                                const SizedBox(height: 8),
                                ...widget.unlocks.map((u) => Padding(
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 2),
                                      child: Text(
                                        u,
                                        style: const TextStyle(
                                            fontSize: 13, color: Colors.white70),
                                      ),
                                    )),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 40),
                        const Text(
                          '点击任意处继续',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white54,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _dismiss() {
    widget.onDismiss();
  }
}

class _Particle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double delay;

  _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.delay,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxDistance = size.width * 0.5;

    for (final p in particles) {
      final adjustedProgress = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (adjustedProgress <= 0) continue;

      // ease out
      final t = 1 - pow(1 - adjustedProgress, 2);
      final distance = t * maxDistance * p.speed;
      final opacity = 1 - adjustedProgress;

      final dx = cos(p.angle) * distance;
      final dy = sin(p.angle) * distance;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        center.translate(dx, dy),
        p.size * (1 - adjustedProgress * 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 解锁新节点/技能的弹窗提示
class UnlockToast {
  static void show(BuildContext context, List<String> unlocks) {
    if (unlocks.isEmpty) return;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 100,
        left: 20,
        right: 20,
        child: _UnlockToastWidget(
          unlocks: unlocks,
          onDismissed: () => entry.remove(),
        ),
      ),
    );

    overlay.insert(entry);
  }
}

class _UnlockToastWidget extends StatefulWidget {
  final List<String> unlocks;
  final VoidCallback onDismissed;

  const _UnlockToastWidget({required this.unlocks, required this.onDismissed});

  @override
  State<_UnlockToastWidget> createState() => _UnlockToastWidgetState();
}

class _UnlockToastWidgetState extends State<_UnlockToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );

    _ctrl.forward();

    // 3 秒后消失
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _ctrl.reverse().then((_) {
          if (mounted) widget.onDismissed();
        });
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.accent, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lock_open, color: AppTheme.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '🔓 解锁新技能！',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.unlocks.join('、'),
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
