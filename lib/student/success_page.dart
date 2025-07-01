// Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): 2025-06-29 06:40:05
// Current User's Login: devivekrt

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';

class ProgressSuccessPage extends StatefulWidget {
  // Title text for the page
  final String title;

  // Message shown during loading
  final String loadingMessage;

  // Message shown on completion
  final String completedMessage;

  // Function that performs the async work
  // Returns a bool indicating success/failure
  final Future<bool> Function() taskFunction;

  // What to do when complete
  final VoidCallback? onComplete;

  // How long to show the success state before auto-continuing
  final Duration autoContinueDelay;

  // Custom background color
  final Color backgroundColor;

  // Custom accent color (for circle, buttons)
  final Color accentColor;

  // Optional subtitle for additional context
  final String? subtitle;

  const ProgressSuccessPage({
    super.key,
    this.title = 'Processing',
    this.subtitle,
    this.loadingMessage = 'Please wait...',
    this.completedMessage = 'All Set!',
    required this.taskFunction,
    this.onComplete,
    this.autoContinueDelay = const Duration(seconds: 1),
    this.backgroundColor = const Color(0xFF142E4F),
    this.accentColor = Colors.blue,
  });

  @override
  _ProgressSuccessPageState createState() => _ProgressSuccessPageState();
}

class _ProgressSuccessPageState extends State<ProgressSuccessPage> with TickerProviderStateMixin {
  late AnimationController _circleController;
  late AnimationController _checkController;
  late AnimationController _scaleController;
  late AnimationController _loadingController;

  late Animation<double> _circleAnimation;
  late Animation<double> _checkAnimation;
  late Animation<double> _scaleAnimation;

  bool _animationCompleted = false;
  bool _taskCompleted = false;
  bool _taskSuccess = false;
  bool _isProcessing = true;
  String _statusText = '';
  String? _errorText;

  @override
  void initState() {
    super.initState();

    _statusText = widget.loadingMessage;

    // Controller for the circular loading animation
    _loadingController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    // Controller for the outer circle animation
    _circleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Controller for the checkmark animation
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Controller for the scale effect
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Animation for the outer circle
    _circleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _circleController,
        curve: Curves.easeOutQuart,
      ),
    );

    // Animation for the checkmark
    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Animation for scaling effect
    _scaleAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.2),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0),
        weight: 60,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeOutBack,
      ),
    );

    // Add listeners for animation completion
    _checkController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _animationCompleted = true;
        });

        // If task already completed, auto-continue after delay
        if (_taskCompleted && _taskSuccess) {
          _scheduleContinue();
        }
      }
    });

    // Execute the task
    _executeTask();
  }

  // Execute the provided task function
  Future<void> _executeTask() async {
    try {
      final result = await widget.taskFunction();

      setState(() {
        _taskCompleted = true;
        _taskSuccess = result;
        _isProcessing = false;
        _statusText = result ? widget.completedMessage : 'Completed with issues';
      });

      if (result) {
        // Dispose of the loading animation
        _loadingController.stop();

        // Play the success animations in sequence
        _scaleController.forward();
        await Future.delayed(const Duration(milliseconds: 150));
        _circleController.forward();
        await Future.delayed(const Duration(milliseconds: 400));
        _checkController.forward();

        // If animation already completed, schedule continue
        if (_animationCompleted) {
          _scheduleContinue();
        }
      }
    } catch (e) {
      setState(() {
        _taskCompleted = true;
        _taskSuccess = false;
        _isProcessing = false;
        _errorText = e.toString();
        _statusText = 'Error occurred';
      });

      // Stop the loading animation
      _loadingController.stop();

      // Scale up the error icon
      _scaleController.forward();
    }
  }

  void _scheduleContinue() {
    if (widget.onComplete != null) {
      Future.delayed(widget.autoContinueDelay, widget.onComplete!);
    }
  }

  @override
  void dispose() {
    _circleController.dispose();
    _checkController.dispose();
    _scaleController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double width = size.width;
    final double animationSize = math.min(width * 0.5, 200);

    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.backgroundColor,
                Color.lerp(widget.backgroundColor, Colors.black, 0.3)!,
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title with optional subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 60),

              // Animated Icon or Spinner
              if (_isProcessing)
              // Show spinner while processing
                AnimatedBuilder(
                  animation: _loadingController,
                  builder: (_, __) {
                    return SizedBox(
                      width: animationSize,
                      height: animationSize,
                      child: CustomPaint(
                        painter: LoadingCirclePainter(
                          progress: _loadingController.value,
                          color: widget.accentColor,
                        ),
                      ),
                    );
                  },
                )
              else if (_taskSuccess)
              // Show success animation
                AnimatedBuilder(
                  animation: Listenable.merge([_circleAnimation, _checkAnimation, _scaleAnimation]),
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: SizedBox(
                        width: animationSize,
                        height: animationSize,
                        child: CustomPaint(
                          painter: SuccessIconPainter(
                            circleProgress: _circleAnimation.value,
                            checkProgress: _checkAnimation.value,
                            accentColor: widget.accentColor,
                          ),
                          size: Size(animationSize, animationSize),
                        ),
                      ),
                    );
                  },
                )
              else
              // Show error icon with animation
                AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: animationSize,
                        height: animationSize,
                        decoration: BoxDecoration(
                          color: Colors.red.shade800,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.error_outline,
                          size: animationSize * 0.6,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 48),

              // Status Text with animated appearance
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _statusText,
                  key: ValueKey(_statusText),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: _taskCompleted ? FontWeight.bold : FontWeight.normal,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Error details if any
              if (_errorText != null)
                AnimatedOpacity(
                  opacity: _errorText != null ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorText!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              const SizedBox(height: 60),

              // Continue button - only shows when task is completed
              if (_taskCompleted)
                AnimatedOpacity(
                  opacity: _animationCompleted ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _taskSuccess ? widget.accentColor : Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                      elevation: 8,
                      shadowColor: _taskSuccess ? widget.accentColor.withOpacity(0.6) : Colors.red.withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: _animationCompleted ? widget.onComplete : null,
                    child: Text(
                      _taskSuccess ? 'Continue' : 'Try Again',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoadingCirclePainter extends CustomPainter {
  final double progress;
  final Color color;

  LoadingCirclePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.4;

    // Draw track (background circle)
    final trackPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;

    canvas.drawCircle(center, radius, trackPaint);

    // Draw loading arc
    final loadingPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2; // Start from top
    final sweepAngle = 2 * math.pi * 0.7; // Sweep 70% of the circle

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle + (2 * math.pi * progress),
      sweepAngle,
      false,
      loadingPaint,
    );
  }

  @override
  bool shouldRepaint(covariant LoadingCirclePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class SuccessIconPainter extends CustomPainter {
  final double circleProgress;
  final double checkProgress;
  final Color accentColor;

  SuccessIconPainter({
    required this.circleProgress,
    required this.checkProgress,
    this.accentColor = Colors.blue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.4;

    // Draw the complete background circle first
    final backgroundPaint = Paint()
      ..color = accentColor.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw outer circle
    final outerCirclePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    if (circleProgress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * circleProgress,
        false,
        outerCirclePaint,
      );
    }

    // Draw the filled circle background
    if (circleProgress >= 0.95) {
      final innerCirclePaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.fill;

      final innerRadius = radius * 0.85;
      canvas.drawCircle(center, innerRadius, innerCirclePaint);
    }

    // Draw the checkmark
    if (checkProgress > 0) {
      final checkPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;

      final checkSize = radius * 0.6;
      final startPoint = Offset(center.dx - checkSize * 0.5, center.dy + checkSize * 0.1);
      final middlePoint = Offset(center.dx - checkSize * 0.1, center.dy + checkSize * 0.5);
      final endPoint = Offset(center.dx + checkSize * 0.5, center.dy - checkSize * 0.5);

      final path = Path();

      if (checkProgress <= 0.5) {
        // Animate first part of the check (to the middle point)
        final progress = checkProgress * 2; // Scale to 0-1 for this segment
        final currentX = startPoint.dx + (middlePoint.dx - startPoint.dx) * progress;
        final currentY = startPoint.dy + (middlePoint.dy - startPoint.dy) * progress;

        path.moveTo(startPoint.dx, startPoint.dy);
        path.lineTo(currentX, currentY);
      } else {
        // Animate second part of the check (middle to end)
        path.moveTo(startPoint.dx, startPoint.dy);
        path.lineTo(middlePoint.dx, middlePoint.dy);

        final progress = (checkProgress - 0.5) * 2; // Scale to 0-1 for this segment
        final currentX = middlePoint.dx + (endPoint.dx - middlePoint.dx) * progress;
        final currentY = middlePoint.dy + (endPoint.dy - middlePoint.dy) * progress;

        path.lineTo(currentX, currentY);
      }

      canvas.drawPath(path, checkPaint);
    }

    // Add subtle glint effect when complete
    if (circleProgress >= 1.0 && checkProgress >= 1.0) {
      final highlightPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withOpacity(0.4),
            Colors.white.withOpacity(0.0),
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(
          center: Offset(center.dx - radius * 0.3, center.dy - radius * 0.3),
          radius: radius * 0.8,
        ));

      canvas.drawCircle(
        Offset(center.dx - radius * 0.3, center.dy - radius * 0.3),
        radius * 0.3,
        highlightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SuccessIconPainter oldDelegate) {
    return oldDelegate.circleProgress != circleProgress ||
        oldDelegate.checkProgress != checkProgress ||
        oldDelegate.accentColor != accentColor;
  }
}