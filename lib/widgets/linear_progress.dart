import 'package:flutter/material.dart';

class CustomProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const CustomProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    double progress = currentStep / totalSteps;
    double h = MediaQuery.of(context).size.height;

    return Row(
      children: [
        Expanded(
          child: Stack(
            children: [
              Container(
                height: h * 0.012, // Responsive height
                decoration: BoxDecoration(
                  color: Color(0xFF1940CC),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: h * 0.012,
                  decoration: BoxDecoration(
                    color: Color(0xFF00AEED),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$currentStep of $totalSteps',
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }
}