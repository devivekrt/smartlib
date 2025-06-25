// Welcome Screen Implementation
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:smartlib/student/select_page.dart';

class WelcomeScreen extends StatefulWidget {
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final double boxSize = 90.0;
  final int baseBoxCount = 10;
  final scrollSpeed = 40;

  final List<ScrollController> controllers = List.generate(
    3,
        (_) => ScrollController(),
  );

  late List<List<int>> repeatedBoxIndexes;

  final List<Color> boxColors = [
    Colors.pinkAccent.withOpacity(0.9),
    Colors.lightBlue.withOpacity(0.9),
    Colors.deepPurple.withOpacity(0.9),
    Colors.teal.withOpacity(0.9),
    Colors.orangeAccent.withOpacity(0.9),
    Colors.amber.withOpacity(0.9),
    Colors.greenAccent.withOpacity(0.9),
    Colors.indigoAccent.withOpacity(0.9),
  ];

  final List<IconData> baseIcons = [
    Icons.school,
    Icons.local_library,
    Icons.book,
    Icons.menu_book,
    Icons.event_seat,
    Icons.auto_stories,
    Icons.book_online,
    Icons.bookmark,
    Icons.cast_for_education,
    Icons.library_books,
    Icons.lightbulb,
    Icons.headphones,
    Icons.laptop,
    Icons.tablet,
    Icons.science,
  ];

  late List<List<IconData>> columnIcons;
  List<Timer> _scrollTimers = [];

  @override
  void initState() {
    super.initState();

    repeatedBoxIndexes = List.generate(3, (i) {
      return List.generate(baseBoxCount * 3, (j) => j);
    });

    List<IconData> uniqueIcons = [...baseIcons];
    uniqueIcons.shuffle(Random());

    int iconsPerColumn = uniqueIcons.length ~/ 3;
    columnIcons = [
      uniqueIcons.sublist(0, iconsPerColumn),
      uniqueIcons.sublist(iconsPerColumn, iconsPerColumn * 2),
      uniqueIcons.sublist(iconsPerColumn * 2),
    ];

    // Repeat icon list to fill all box count if needed
    columnIcons = columnIcons.map((list) {
      return List.generate(baseBoxCount * 3, (i) => list[i % list.length]);
    }).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScroll();
    });
  }

  void _startAutoScroll() {
    final List<double> scrollDirections = [-1.0, -1.0, 1.0];

    for (int i = 0; i < controllers.length; i++) {
      final controller = controllers[i];
      final direction = scrollDirections[i];

      final timer = Timer.periodic(Duration(milliseconds: scrollSpeed), (timer) {
        if (!controller.hasClients) return;

        double offset = controller.offset + direction;
        double maxExtent = controller.position.maxScrollExtent;
        double minExtent = controller.position.minScrollExtent;

        if (offset >= maxExtent - 1) {
          controller.jumpTo(minExtent + 1);
        } else if (offset <= minExtent + 1) {
          controller.jumpTo(maxExtent - 1);
        } else {
          controller.jumpTo(offset);
        }
      });

      _scrollTimers.add(timer);
    }
  }

  IconData _getIcon(int columnIndex, int boxIndex) {
    final icons = columnIcons[columnIndex];
    return icons[boxIndex % icons.length];
  }

  Color _getBoxColor(int columnIndex, int boxIndex) {
    return boxColors[(columnIndex + boxIndex) % boxColors.length];
  }

  Widget _buildColumn(int index) {
    final reverse = index == 0;

    return SizedBox(
      width: boxSize,
      height: 390,
      child: ClipRect(
        child: ListView.builder(
          controller: controllers[index],
          reverse: reverse,
          physics: NeverScrollableScrollPhysics(),
          itemCount: repeatedBoxIndexes[index].length,
          itemBuilder: (_, i) => Container(
            margin: EdgeInsets.symmetric(vertical: 25),
            width: boxSize,
            height: boxSize,
            decoration: BoxDecoration(
              color: _getBoxColor(index, i),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Icon(
                _getIcon(index, i),
                size: 40,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Cancel all scroll timers
    for (final timer in _scrollTimers) {
      timer.cancel();
    }

    // Dispose controllers
    for (final controller in controllers) {
      controller.dispose();
    }

    super.dispose();
  }

  void _navigateToSelectPage() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => SelectPage(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 40.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildColumn(0),
                  SizedBox(width: 50),
                  _buildColumn(1),
                  SizedBox(width: 50),
                  _buildColumn(2),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Book your seat\nanywhere to study!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 15),
                  Text(
                    "India's 1st Library Seat Booking\nPlatform",
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 40),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding:
                      EdgeInsets.symmetric(horizontal: 140, vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: _navigateToSelectPage,
                    child: Text("Get Started",
                        style: TextStyle(color: Colors.white, fontSize: 17)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}