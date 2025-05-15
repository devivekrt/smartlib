import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:smartlib/widgets/solid_button.dart';

class LibDetail extends StatefulWidget {
  const LibDetail({super.key});

  @override
  State<LibDetail> createState() => _LibDetailState();
}

class _LibDetailState extends State<LibDetail> {
  bool favorite = false;
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    final String shortText =
        "📍 Central Public Information Officer, IIT Patna, Bihta, Patna (Bihar)";
    final String fullText =
        "$shortText, PIN: 801106. This library offers a peaceful environment, modern facilities, and is open to all students and staff.";

    final gradientBorder = LinearGradient(
      colors: [Color(0xff209CC9), Color(0xffF4C264)],
    );

    final theme = Theme.of(context);
    final border = theme.colorScheme.secondary;

    return Scaffold(
      floatingActionButton: Padding(
        padding: EdgeInsets.all(20),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
          ),
          width: width,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SolidButton(text: "Skip", onPressed: () {}),
              SolidButton(text: "Book Now", onPressed: () {}),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Favorite Icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          favorite = !favorite;
                        });
                      },
                      icon: Icon(
                        favorite ? Icons.favorite : Icons.favorite_border,
                        color: Colors.deepPurpleAccent,
                      ),
                    ),
                  ],
                ),

                // Image Placeholder
                Container(
                  height: height / 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Center(
                    child: Text(
                      "Library Image",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
                const Gap(20),

                // Feature Icons
                Row(
                  children: [
                    Chip(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      side: BorderSide.none,
                      backgroundColor: const Color(0xff1940CC),
                      avatar: const Icon(Icons.wifi, color: Colors.white),
                      label: const Text(
                        'Wi-Fi',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const Gap(10),

                    Chip(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      side: BorderSide.none,
                      backgroundColor: Color(0xff1940CC),
                      avatar: Icon(Icons.camera_rear, color: Colors.white),
                      label: const Text(
                        'CCTV',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const Gap(20),

                // Library Detail Card
                Card(
                  child: Container(
                    width: width,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name and Fee
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "IIT Patna Central Library",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Gap(10),
                                Row(
                                  children: const [
                                    Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 20,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      "4.5/5.0  •  526 reviews",
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            //monthly fee show
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.amber),
                                color: Colors.white.withOpacity(0.05),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    "\$500",
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    "/month",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Gap(10),

                        // Location
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Gap(8),
                            Expanded(
                              child: Text(
                                "📍 Central Public Information Officer, IIT Patna, Bihta, Patna (Bihar), PIN: 801106",
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),

                        const Gap(10),

                        // Student Count
                        gradientBox(
                          "456 Students Enrolled",
                          gradientBorder,
                          width,
                        ),
                      ],
                    ),
                  ),
                ),
                Gap(20),

                // Library detail description
                Card(
                  child: Container(
                    width: width,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // title
                        Text(
                          "About this Library",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // description with "see more"
                        // Description with toggle
                        RichText(
                          text: TextSpan(
                            text: _isExpanded ? fullText : shortText,
                            style: TextStyle(color: Colors.white70),
                            children: [
                              TextSpan(
                                text: _isExpanded ? "  See less" : "  See more",
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w500,
                                ),
                                recognizer:
                                    TapGestureRecognizer()
                                      ..onTap = () {
                                        setState(() {
                                          _isExpanded = !_isExpanded;
                                        });
                                      },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),
                        Divider(color: Colors.white70),

                        Text(
                          "Amenities",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),

                        Wrap(
                          runSpacing: 10,
                          spacing: 20,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.wifi, color: Colors.amber),
                                const SizedBox(height: 4),
                                Text(
                                  "Wi-Fi",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                            // Add more amenities here
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chair, color: Colors.amber),
                                const SizedBox(height: 4),
                                Text(
                                  "Seating",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.charging_station,
                                  color: Colors.amber,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Charging-Socket",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Gap(20),
                //Library rule and information
                Card(
                  child: Container(
                    width: width,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // title
                        Text(
                          "Library Rule & Information",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Rules List
                        RuleItem("Maintain silence in the library."),
                        RuleItem("Mobile phones should be on silent mode."),
                        RuleItem("No food or drinks allowed."),
                        RuleItem("Books must be returned within 14 days."),
                        RuleItem("Handle books and property with care."),
                      ],
                    ),
                  ),
                ),

                //Review and rating
                Card(
                  child: Container(
                    width: width,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // title
                        Text(
                          "Reviews and Ratings",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
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

  Widget gradientBox(String text, Gradient gradient, double? width) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient, // Outer gradient border
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(2), // Thickness of the border
      child: Container(
        width: width,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Color(0xff212121), // Inner content background
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.people),
            Gap(8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RuleItem extends StatelessWidget {
  final String text;
  const RuleItem(this.text, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(backgroundColor: Colors.amber, radius: 5),
          Gap(10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
