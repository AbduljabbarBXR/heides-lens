import 'dart:async';
import 'package:flutter/material.dart';
import 'package:heides_lens/shared/themes/app_colors.dart';
import 'package:heides_lens/shared/logos.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingOverlay({super.key, required this.onComplete});

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> with TickerProviderStateMixin {
  int _currentStep = 0;
  int logoId = 1;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _autoProgress;

  final _steps = const [
    _OnboardingStep(
      icon: Icons.account_tree_rounded,
      title: 'Visualize Your Code',
      subtitle: 'See your entire codebase as an interactive mesh. Understand dependencies, find patterns, and navigate architecture at a glance.',
      color: Color(0xFF6366F1),
      mockContent: _GraphMock(),
    ),
    _OnboardingStep(
      icon: Icons.verified_rounded,
      title: 'Review & Fix',
      subtitle: 'Automated code review finds bugs, security issues, and improvements. Click any finding to see the exact location.',
      color: Color(0xFFF59E0B),
      mockContent: _ReviewMock(),
    ),
    _OnboardingStep(
      icon: Icons.shield_rounded,
      title: 'Local & Private',
      subtitle: 'HEIDES runs as one small binary on your machine — no account, no cloud. Graph facts and findings stay where your code is.',
      color: Color(0xFFEF4444),
      mockContent: _HeidesMock(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() => logoId = prefs.getInt('logo_choice') ?? 1);
      }
    });
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    _fadeController.forward();
    _slideController.forward();
    _startAutoProgress();
  }

  void _startAutoProgress() {
    _autoProgress = Timer.periodic(const Duration(seconds: 6), (_) {
      if (_currentStep < _steps.length - 1) {
        _nextStep();
      } else {
        _autoProgress?.cancel();
      }
    });
  }

  void _nextStep() {
    _autoProgress?.cancel();
    if (_currentStep < _steps.length - 1) {
      _fadeController.reverse().then((_) {
        setState(() => _currentStep++);
        _fadeController.forward();
        _slideController.reset();
        _slideController.forward();
        _startAutoProgress();
      });
    }
  }

  void _prevStep() {
    _autoProgress?.cancel();
    if (_currentStep > 0) {
      _fadeController.reverse().then((_) {
        setState(() => _currentStep--);
        _fadeController.forward();
        _slideController.reset();
        _slideController.forward();
        _startAutoProgress();
      });
    }
  }

  Future<void> _complete() async {
    _autoProgress?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    widget.onComplete();
  }

  @override
  void dispose() {
    _autoProgress?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];

    return Material(
      color: Colors.black87,
      child: Stack(
        children: [
          // Animated background gradient
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [
                    step.color.withOpacity(0.15),
                    Colors.black87,
                  ],
                ),
              ),
            ),
          ),

          // Main content
          Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Step indicator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_steps.length, (i) {
                            final isActive = i == _currentStep;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: isActive ? 32 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isActive ? step.color : AppColors.textMuted.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 48),

                        // Chosen logo
                        HeidesLogoFull(id: logoId, markSize: 40, fontSize: 26),
                        const SizedBox(height: 24),

                        // Icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: step.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: step.color.withOpacity(0.3)),
                          ),
                          child: Icon(step.icon, color: step.color, size: 40),
                        ),
                        const SizedBox(height: 32),

                        // Title
                        Text(
                          step.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),

                        // Subtitle
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 500),
                          child: Text(
                            step.subtitle,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 16,
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Mock UI preview
                        Container(
                          width: double.infinity,
                          height: 220,
                          decoration: BoxDecoration(
                            color: AppColors.surface.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: step.mockContent,
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Navigation
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_currentStep > 0)
                              TextButton(
                                onPressed: _prevStep,
                                child: Text(
                                  'Back',
                                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                                ),
                              ),
                            const SizedBox(width: 16),
                            if (_currentStep < _steps.length - 1) ...[
                              ElevatedButton(
                                onPressed: _nextStep,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: step.color,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Next'),
                              ),
                              const SizedBox(width: 12),
                              TextButton(
                                onPressed: _complete,
                                child: Text(
                                  'Skip',
                                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
                                ),
                              ),
                            ] else
                              ElevatedButton(
                                onPressed: _complete,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: step.color,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Get Started', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ),
          ),

          // Skip button (top right)
          Positioned(
            top: 24,
            right: 24,
            child: TextButton(
              onPressed: _complete,
              child: Text(
                'Skip Tour',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
              ),
            ),
          ),

          // Heides Lens logo (top left)
          Positioned(
            top: 24,
            left: 24,
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(Icons.auto_awesome, color: AppColors.background, size: 16),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Heides Lens',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingStep {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget mockContent;

  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.mockContent,
  });
}

// --- Mock UI Widgets ---

class _GraphMock extends StatelessWidget {
  const _GraphMock();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Nodes
        ...List.generate(6, (i) {
          final colors = [Color(0xFF6366F1), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF8B5CF6), Color(0xFF06B6D4)];
          final positions = [
            const Alignment(-0.5, -0.3),
            const Alignment(0.3, -0.4),
            const Alignment(0.6, 0.1),
            const Alignment(-0.3, 0.4),
            const Alignment(0.1, 0.3),
            const Alignment(-0.6, 0.0),
          ];
          return Align(
            alignment: positions[i],
            child: AnimatedContainer(
              duration: Duration(milliseconds: 600 + i * 100),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors[i].withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors[i].withOpacity(0.5)),
              ),
              child: Icon(
                [Icons.circle, Icons.code, Icons.storage, Icons.web, Icons.smartphone, Icons.palette][i],
                color: colors[i],
                size: 20,
              ),
            ),
          );
        }),
        // Edges (simple lines via CustomPaint would be ideal, using Container lines)
        Positioned.fill(
          child: CustomPaint(
            painter: _EdgePainter(),
          ),
        ),
      ],
    );
  }
}

class _EdgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textMuted.withOpacity(0.2)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final nodes = [
      Offset(size.width * 0.25, size.height * 0.35),
      Offset(size.width * 0.65, size.height * 0.3),
      Offset(size.width * 0.8, size.height * 0.55),
      Offset(size.width * 0.35, size.height * 0.7),
      Offset(size.width * 0.55, size.height * 0.65),
      Offset(size.width * 0.2, size.height * 0.5),
    ];

    final connections = [
      [0, 1], [1, 2], [0, 3], [3, 4], [1, 4], [0, 5], [5, 3],
    ];

    for (final conn in connections) {
      canvas.drawLine(nodes[conn[0]], nodes[conn[1]], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ReviewMock extends StatelessWidget {
  const _ReviewMock();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              _statChip('3 Issues', Color(0xFFEF4444)),
              const SizedBox(width: 8),
              _statChip('1 Warning', Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              _statChip('12 Passed', Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: 12),
          _findingRow(Icons.error_outline, Color(0xFFEF4444), 'Shell injection risk', 'diff.ts:14'),
          const SizedBox(height: 6),
          _findingRow(Icons.warning_amber_rounded, Color(0xFFF59E0B), 'Hardcoded metadata', 'pipeline.ts:45'),
          const SizedBox(height: 6),
          _findingRow(Icons.check_circle_outline, Color(0xFF10B981), 'Auth middleware valid', 'auth.ts:8'),
        ],
      ),
    );
  }

  Widget _statChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _findingRow(IconData icon, Color color, String title, String location) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 12))),
          Text(location, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _HeidesMock extends StatelessWidget {
  const _HeidesMock();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _row(Icons.memory_rounded, 'HEIDES engine', 'running locally', true, Color(0xFF10B981)),
          const SizedBox(height: 8),
          _row(Icons.account_tree_rounded, 'spine.describe', 'workspace graph', true, Color(0xFF10B981)),
          const SizedBox(height: 8),
          _row(Icons.verified_rounded, 'harmony.report', 'deterministic findings', true, Color(0xFF10B981)),
          const SizedBox(height: 8),
          _row(Icons.cloud_off_rounded, 'cloud sync', 'not required', false, AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String name, String status, bool ok, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Icon(ok ? Icons.check_circle_rounded : Icons.remove_circle_outline, color: color, size: 14),
        ],
      ),
    );
  }
}
