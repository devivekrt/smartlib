import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:smartlib/student/select_page.dart';
import 'package:smartlib/widgets/solid_button.dart';

class WelcomeScreen extends StatefulWidget {
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final int baseBoxCount = 15;
  final scrollSpeed = 40;

  final List<ScrollController> controllers = List.generate(
    3,
    (_) => ScrollController(),
  );

  late List<List<int>> repeatedBoxIndexes;

  final List<Color> boxColors = [
    // Original colors
    Colors.pinkAccent.withOpacity(0.9),
    Colors.lightBlue.withOpacity(0.9),
    Colors.deepPurple.withOpacity(0.9),
    Colors.teal.withOpacity(0.9),
    Colors.orangeAccent.withOpacity(0.9),
    Colors.amber.withOpacity(0.9),
    Colors.greenAccent.withOpacity(0.9),
    Colors.indigoAccent.withOpacity(0.9),

    // New vibrant colors
    Color(0xFFFF1744).withOpacity(0.85), // Vibrant Red
    Color(0xFFFF9100).withOpacity(0.85), // Bright Orange
    Color(0xFF00E676).withOpacity(0.85), // Neon Green
    Color(0xFF2979FF).withOpacity(0.85), // Electric Blue
    Color(0xFFD500F9).withOpacity(0.85), // Vivid Purple
    Color(0xFFFFEA00).withOpacity(0.85), // Sharp Yellow
    Color(0xFFFF4081).withOpacity(0.85), // Hot Pink
    Color(0xFF00B8D4).withOpacity(0.85), // Aqua Blue
    Color(0xFF64DD17).withOpacity(0.85), // Lush Lime
    Color(0xFF00C853).withOpacity(0.85), // Rich Green
    Color(0xFFFF6D00).withOpacity(0.85), // Strong Orange
    Color(0xFF6200EA).withOpacity(0.85), // Deep Violet
  ];

  final List<IconData> baseIcons = [
    // Original icons
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

    // Additional icons
    Icons.article,
    Icons.collections_bookmark,
    Icons.history_edu,
    Icons.biotech,
    Icons.psychology,
    Icons.devices,
    Icons.chair,
    Icons.desktop_windows,
    Icons.calculate,
    Icons.architecture,
    Icons.public,
    Icons.note_alt,
    Icons.chair_alt,
    Icons.hub,
    Icons.emoji_objects_outlined,
    Icons.smart_display,
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
    columnIcons =
        columnIcons.map((list) {
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

      final timer = Timer.periodic(Duration(milliseconds: scrollSpeed), (
        timer,
      ) {
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
    final double boxSize = MediaQuery.of(context).size.width * 0.21;

    final reverse = index == 0;

    return SizedBox(
      width: boxSize,
      height: MediaQuery.of(context).size.height * 0.5,
      child: ClipRect(
        child: ListView.builder(
          controller: controllers[index],
          reverse: reverse,
          physics: NeverScrollableScrollPhysics(),
          itemCount: repeatedBoxIndexes[index].length,
          itemBuilder:
              (_, i) => Container(
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
          pageBuilder: (context, animation, secondaryAnimation) => SelectPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var begin = Offset(1.0, 0.0);
            var end = Offset.zero;
            var curve = Curves.ease;

            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);

            return SlideTransition(position: offsetAnimation, child: child);
          },
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.blueGrey.shade900],
                stops: [0.6, 1.0],
              ),
            ),
          ),

          // Scrolling columns
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
          // Bottom section
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 50),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Book your seat\nanywhere to study!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 33,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Gap(20),
                  Text(
                    "India's 1st Library Seat Booking\nPlatform",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 30),
                  SolidButton(
                    text: "Get Started",
                    onPressed: _navigateToSelectPage,
                    width: double.infinity,
                    height: 60,
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
