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

  const ProgressSuccessPage({
    super.key,
    this.title = 'Processing',
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

class _ProgressSuccessPageState extends State<ProgressSuccessPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _circleAnimation;
  late Animation<double> _checkAnimation;

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

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Animation for the outer circle
    _circleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    // Animation for the checkmark
    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.7, 1.0, curve: Curves.elasticOut),
      ),
    );

    // Add a listener to set the animation completed flag
    _controller.addStatusListener((status) {
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
        // Start the success animation
        _controller.forward();

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
    }
  }

  void _scheduleContinue() {
    if (widget.onComplete != null) {
      Future.delayed(widget.autoContinueDelay, widget.onComplete!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),

              // Animated Icon or Spinner
              if (_isProcessing)
              // Show spinner while processing
                SizedBox(
                  width: width/3,
                  height: width/3,
                  child: CircularProgressIndicator(
                    color: widget.accentColor,
                    strokeWidth: 8,
                  ),
                )
              else if (_taskSuccess)
              // Show success animation
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return SizedBox(
                      width: width/2,
                      height: width/2,
                      child: CustomPaint(
                        painter: SuccessIconPainter(
                          circleProgress: _circleAnimation.value,
                          checkProgress: _checkAnimation.value,
                          accentColor: widget.accentColor,
                        ),
                      ),
                    );
                  },
                )
              else
              // Show error icon
                Icon(
                  Icons.error_outline,
                  size: width/3,
                  color: Colors.red,
                ),

              const SizedBox(height: 40),

              // Status Text
              Text(
                _statusText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),

              // Error details if any
              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _errorText!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 40),

              // Continue button - only shows when task is completed
              if (_taskCompleted)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _taskSuccess ? widget.accentColor : Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: widget.onComplete,
                  child: Text(
                    _taskSuccess ? 'Continue' : 'Try Again',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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
    final radius = math.min(size.width, size.height) / 2;
    final outerCircleRadius = radius;
    final whiteCircleRadius = radius - 30;
    final colorFilledRadius = radius - 35;

    // Draw outer circle
    final outerCirclePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    if (circleProgress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerCircleRadius),
        -math.pi / 2,
        2 * math.pi * circleProgress,
        false,
        outerCirclePaint,
      );
    }

    // Draw inner white circle
    if (circleProgress >= 0.9) {
      final innerCirclePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20.0;

      canvas.drawCircle(center, whiteCircleRadius, innerCirclePaint);
    }

    // Draw blue filled background for the check
    if (circleProgress >= 1.0) {
      final backgroundPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, colorFilledRadius, backgroundPaint);
    }

    // Draw the checkmark
    if (checkProgress > 0) {
      final checkPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20.0
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;

      final startPoint = Offset(center.dx - radius * 0.3, center.dy + radius * 0.1);
      final middlePoint = Offset(center.dx, center.dy + radius * 0.3);
      final endPoint = Offset(center.dx + radius * 0.4, center.dy - radius * 0.3);

      final path = Path();

      if (checkProgress <= 0.5) {
        final progress = checkProgress * 2;
        final currentX = startPoint.dx + (middlePoint.dx - startPoint.dx) * progress;
        final currentY = startPoint.dy + (middlePoint.dy - startPoint.dy) * progress;

        path.moveTo(startPoint.dx, startPoint.dy);
        path.lineTo(currentX, currentY);
      } else {
        path.moveTo(startPoint.dx, startPoint.dy);
        path.lineTo(middlePoint.dx, middlePoint.dy);

        final progress = (checkProgress - 0.5) * 2;
        final currentX = middlePoint.dx + (endPoint.dx - middlePoint.dx) * progress;
        final currentY = middlePoint.dy + (endPoint.dy - middlePoint.dy) * progress;

        path.lineTo(currentX, currentY);
      }

      canvas.drawPath(path, checkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SuccessIconPainter oldDelegate) {
    return oldDelegate.circleProgress != circleProgress ||
        oldDelegate.checkProgress != checkProgress ||
        oldDelegate.accentColor != accentColor;
  }
}