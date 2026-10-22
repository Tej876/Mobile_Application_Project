import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/queue_provider.dart';
import 'auth_screen.dart';
import 'patient/select_department_screen.dart';
import 'patient/live_status_screen.dart';
import 'admin/dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _waveAnimation;
  late Animation<double> _secondaryWaveAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _textScaleAnimation;
  late Animation<Offset> _textSlideAnimation;

  @override
  void initState() {
    super.initState();

    // Slower, more cinematic transition (3.2s total flow)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    // Primary wave flows down leisurely and smoothly
    _waveAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.08, 0.75, curve: Curves.easeInOutCubic),
    );

    // Secondary liquid trail slightly ahead/offset
    _secondaryWaveAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.04, 0.70, curve: Curves.easeInOutCubic),
    );

    // Text & logo appear only AFTER the wave flows down and covers the screen
    _textFadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.74, 0.95, curve: Curves.easeIn),
    );

    _textScaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.74, 0.98, curve: Curves.easeOutBack),
      ),
    );

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.74, 0.96, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
    _handleNavigation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleNavigation() async {
    // 1. Wait for the flow and text entrance to complete
    try {
      await _controller.forward().orCancel;
    } catch (_) {}

    // 2. Stay on the fully filled branded screen for a little while (~1.8 seconds)
    await Future.delayed(const Duration(milliseconds: 1800));

    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Wait until AuthProvider finishes loading its session state from Firebase
    while (authProvider.isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }

    if (authProvider.currentUser != null) {
      if (authProvider.currentUser!.role == 'admin') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
      } else {
        final queueProvider = Provider.of<QueueProvider>(context, listen: false);
        final active = await queueProvider.findActivePatientToken(authProvider.currentUser!.uid);
        if (!mounted) return;

        if (active != null && active['departmentId'] != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => LiveStatusScreen(departmentId: active['departmentId'].toString()),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SelectDepartmentScreen()),
          );
        }
      }
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
  }

  Widget _buildBranding() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'QueueLess',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: const Color(0xFFF6E7E2), // Blush
                fontSize: 44,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.1,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          'Calm, transparent clinic queues.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFFE6CFC8), // Peach
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6E7E2), // Blush
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _waveAnimation.value;
          final secProgress = _secondaryWaveAnimation.value;
          final size = MediaQuery.of(context).size;

          return Stack(
            children: [
              // 1. Base Layer: Blush Canvas
              Container(
                width: size.width,
                height: size.height,
                color: const Color(0xFFF6E7E2), // Blush
              ),

              // 2. Secondary Wave Layer: Dusty Plum trail
              ClipPath(
                clipper: WaveDripClipper(
                  progress: secProgress,
                  secondaryOffset: 35.0,
                ),
                child: Container(
                  width: size.width,
                  height: size.height,
                  color: const Color(0xFF7E6570).withValues(alpha: 0.45), // Plum
                ),
              ),

              // 3. Primary Wave Layer: Maroon -> Charcoal
              ClipPath(
                clipper: WaveDripClipper(
                  progress: progress,
                  secondaryOffset: 0.0,
                ),
                child: Container(
                  width: size.width,
                  height: size.height,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF33252B), // Charcoal
                        Color(0xFF593E47), // Maroon
                      ],
                    ),
                  ),
                  child: FadeTransition(
                    opacity: _textFadeAnimation,
                    child: SlideTransition(
                      position: _textSlideAnimation,
                      child: ScaleTransition(
                        scale: _textScaleAnimation,
                        child: Center(
                          child: _buildBranding(),
                        ),
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

/// Custom clipper that renders the organic wave / liquid drip shape from the sketch
class WaveDripClipper extends CustomClipper<Path> {
  final double progress; // 0.0 -> 1.0
  final double secondaryOffset;

  WaveDripClipper({required this.progress, this.secondaryOffset = 0.0});

  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    // At progress = 0: top wave drip rests at ~28% height (matching the drawing)
    // At progress = 1: currentBase reaches past 135% height so the entire screen is fully filled
    final startBase = h * 0.28 + secondaryOffset;
    final endBase = h * 1.35 + secondaryOffset;
    final currentBase = startBase + (endBase - startBase) * progress;

    // Dynamic drip amplitudes that smoothly flatten out as the screen fills
    final dripScale = (1.0 - progress * 0.4);
    final leftDripDepth = h * 0.30 * dripScale;
    final midPeakHeight = h * 0.16 * dripScale;
    final rightDripDepth = h * 0.22 * dripScale;

    path.moveTo(0, 0);
    path.lineTo(0, currentBase);

    // 1. Big left rounded drip (matching the deep left lobe in sketch)
    path.cubicTo(
      0,
      currentBase + leftDripDepth * 0.75,
      w * 0.10,
      currentBase + leftDripDepth,
      w * 0.26,
      currentBase + leftDripDepth,
    );

    // 2. Upward curve to the middle inverted peak
    path.cubicTo(
      w * 0.42,
      currentBase + leftDripDepth,
      w * 0.48,
      currentBase - midPeakHeight,
      w * 0.58,
      currentBase - midPeakHeight,
    );

    // 3. Downward curve to the narrower right drip
    path.cubicTo(
      w * 0.68,
      currentBase - midPeakHeight,
      w * 0.72,
      currentBase + rightDripDepth,
      w * 0.80,
      currentBase + rightDripDepth,
    );

    // 4. Upward curve to the right edge
    path.cubicTo(
      w * 0.88,
      currentBase + rightDripDepth,
      w * 0.94,
      currentBase - h * 0.01,
      w,
      currentBase - h * 0.01,
    );

    path.lineTo(w, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant WaveDripClipper oldClipper) {
    return oldClipper.progress != progress ||
        oldClipper.secondaryOffset != secondaryOffset;
  }
}
