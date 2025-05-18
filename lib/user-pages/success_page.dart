import 'package:flutter/material.dart';
import 'dart:math' as math;

class SuccessPage extends StatefulWidget {
  final VoidCallback? onContinue;

  const SuccessPage({super.key, this.onContinue});

  @override
  _SuccessPageState createState() => _SuccessPageState();
}

class _SuccessPageState extends State<SuccessPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _circleAnimation;
  late Animation<double> _checkAnimation;
  bool _animationCompleted = false; // Add this state variable


  @override
  void initState() {
    super.initState();

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
      }
    });
    // Start the animation when the widget is built

    _controller.forward();
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'All Set',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 40),

            // Animated Success Icon
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
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 40),
            const Text(
              'You are ready to go',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 60),

            // Optional: Add a continue button if needed
            Opacity(
              opacity: _animationCompleted ? 1.0 : 0.0,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () {
                  if (widget.onContinue != null) {
                    widget.onContinue!();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SuccessIconPainter extends CustomPainter {
  final double circleProgress;
  final double checkProgress;

  SuccessIconPainter({
    required this.circleProgress,
    required this.checkProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    // Constants for circle spacing
    final outerCircleRadius = radius;
    final whiteCircleRadius = radius - 30; // Increased gap (was radius - 12)
    final blueFilledRadius = radius - 35; // Adjusted accordingly (was radius - 25)


    // Draw outer circle (blue ring)
    final outerCirclePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    if (circleProgress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerCircleRadius),
        -math.pi / 2, // Start from top
        2 * math.pi * circleProgress, // How much of the circle to draw
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
        ..color = Colors.blue[500]!
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, blueFilledRadius, backgroundPaint);
    }

    // Draw the checkmark
    if (checkProgress > 0) {
      final checkPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20.0
        ..strokeJoin =StrokeJoin.round
        ..strokeCap = StrokeCap.round;

      // First point of the checkmark (bottom left)
      final startPoint = Offset(center.dx - radius * 0.3, center.dy + radius * 0.1);
      // Middle point (bottom part of checkmark)
      final middlePoint = Offset(center.dx , center.dy + radius * 0.3);
      // End point (top right of checkmark)
      final endPoint = Offset(center.dx + radius * 0.4, center.dy - radius * 0.3);

      // Calculate points along the path based on animation progress
      final path = Path();

      if (checkProgress <= 0.5) {
        // Animate first part of checkmark (left to middle)
        final progress = checkProgress * 2; // Scale to 0-1 for this segment
        final currentX = startPoint.dx + (middlePoint.dx - startPoint.dx) * progress;
        final currentY = startPoint.dy + (middlePoint.dy - startPoint.dy) * progress;

        path.moveTo(startPoint.dx, startPoint.dy);
        path.lineTo(currentX, currentY);
      } else {
        // First segment is complete
        path.moveTo(startPoint.dx, startPoint.dy);
        path.lineTo(middlePoint.dx, middlePoint.dy);

        // Animate second part of checkmark (middle to right)
        final progress = (checkProgress - 0.5) * 2; // Scale to 0-1 for this segment
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
        oldDelegate.checkProgress != checkProgress;
  }
}