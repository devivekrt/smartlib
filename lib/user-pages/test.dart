import 'package:flutter/material.dart';

class LocationAccessScreen extends StatelessWidget {
  const LocationAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: w * 0.05, vertical: h * 0.05),
              child: CustomProgressBar(currentStep: 3, totalSteps: 3),
            ),
            SizedBox(
              height: h/12,
            ),
            // Main Body Content
            Expanded(
              child: Column(
                // mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Location Icon
                  Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF012634),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(30),
                    child: const Icon(
                      Icons.location_on,
                      color: Color(0xFF00BBFF),
                      size: 100,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Title
                  const Text(
                    "Your Location?",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Subtitle
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      "Allow Location So that we can fetch nerby library",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Primary Button
                  SizedBox(
                    width: w * 0.8,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        // add geolocator here
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BFFF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        "Allow Location Access",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Manual Entry Link
                  GestureDetector(
                    onTap: () {
                      // add manual entry logic here
                    },
                    child: const Text(
                      "Enter Location Manually",
                      style: TextStyle(
                        color: Colors.white,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// PROGRESS BAR
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