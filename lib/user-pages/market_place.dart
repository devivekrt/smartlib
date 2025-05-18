import 'package:flutter/material.dart';
import 'package:smartlib/user-pages/home_page.dart';
import 'package:smartlib/widgets/solid_button.dart';

import '../theme/theme.dart';

class MarketPlace extends StatefulWidget {
  // Add signup parameter to determine which UI to show
  final bool isSignedUp;

  const MarketPlace({
    super.key,
    required this.isSignedUp, // Default to true if not specified
  });

  @override
  State<MarketPlace> createState() => _MarketPlaceState();
}

class _MarketPlaceState extends State<MarketPlace> {
  final List<Map<String, dynamic>> libraries = [
    {
      "name": "IIT Patna Central Library",
      "rating": 4.5,
      "reviews": 526,
      "students": 456,
      "fee": 500,
      "tag": "Popular",
    },
    {
      "name": "Delhi Tech Library",
      "rating": 4.2,
      "reviews": 300,
      "students": 350,
      "fee": 450,
      "tag": "Open Now",
    },
    {
      "name": "Kolkata Research Library",
      "rating": 4.8,
      "reviews": 210,
      "students": 420,
      "fee": 600,
      "tag": "24x7 Access",
    },
  ];

  // Track which tab is active
  bool _showFindNew = true;

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1E2A38),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder:
          (context) => Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Sort By",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 15),
                _buildSortOption("Price: Low to High"),
                _buildSortOption("Price: High to Low"),
                _buildSortOption("Rating: High to Low"),
                _buildSortOption("Most Reviews"),
                _buildSortOption("Most Popular"),
              ],
            ),
          ),
    );
  }

  Widget _buildSortOption(String title) {
    return InkWell(
      onTap: () {
        // Implement sorting logic here
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          title,
          style: TextStyle(fontSize: 16, color: Colors.white70),
        ),
      ),
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1E2A38),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder:
          (context) => Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Filter Options",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 15),
                _buildFilterOption("Rating (4+)"),
                _buildFilterOption("Open Now"),
                _buildFilterOption("24x7 Access"),
                _buildFilterOption("Distance (< 3km)"),
                SizedBox(height: 15),
                SolidButton(
                  text: "Apply Filters",
                  width: double.infinity,
                  height: 45,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildFilterOption(String title) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(title, style: TextStyle(fontSize: 16, color: Colors.white70)),
          Spacer(),
          Switch(
            value: false,
            onChanged: (value) {
              // Implement filter logic here
            },
            activeColor: Colors.blue,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.isSignedUp,
         /* leading:
              widget.isSignedUp
                  ? null // No back button when signed up
                  : IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),*/
          title: const Text(
            "Library Marketplace",
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          elevation: 0,
          actions: [
            // Sort and filter icons always shown
            IconButton(
              icon: Icon(Icons.sort, color: Colors.white),
              onPressed: _showSortOptions,
            ),
            IconButton(
              icon: Icon(Icons.filter_list, color: Colors.white),
              onPressed: _showFilterOptions,
            ),
          ],
        ),
        // Book Later button only shown when signed up
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        bottomNavigationBar:
            widget.isSignedUp
                ? Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: SolidButton(
                    text: "Book Later",
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => HomePage()),
                      );
                    },
                    width: double.infinity,
                  ),
                )
                : null,
        body: Column(
          children: [
            // Only show custom tab buttons when not signed up
            if (!widget.isSignedUp)
              Container(
                height: 70,
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white, width: 0.5),
                ),
                child: Row(
                  children: [
                    // Find New button
                    Expanded(
                      child: SolidButton(
                        text: "Find New",
                        onPressed: () {
                          setState(() {
                            _showFindNew = true;
                          });
                        },
                        buttonColor:
                            _showFindNew ? DarkColor.primary : Colors.transparent,
                        borderColor:
                            _showFindNew ? Colors.transparent : DarkColor.primary,
                        width: double.infinity,
                        height: 50,
                      ),
                    ),
                    SizedBox(width: 8),
                    // Joined button with only border
                    Expanded(
                      child: SolidButton(
                        text: "Joined",
                        onPressed: () {
                          setState(() {
                            _showFindNew = false;
                          });
                        },
                        buttonColor:
                            !_showFindNew ? DarkColor.primary : Colors.transparent,
                        borderColor:
                            !_showFindNew ? Colors.transparent : DarkColor.primary,
                        width: double.infinity,
                        height: 50,
                      ),
                    ),
                  ],
                ),
              ),

            // Library list content
            Expanded(
              child:
                  widget.isSignedUp
                      ? _buildLibraryList(width)
                      : (_showFindNew
                          ? _buildLibraryList(width)
                          : _buildLastJoinedList(width)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryList(double width) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: libraries.length,
      itemBuilder: (context, index) {
        final lib = libraries[index];
        return LibraryCard(
          name: lib["name"],
          rating: lib["rating"],
          reviews: lib["reviews"],
          students: lib["students"],
          fee: lib["fee"],
          tag: lib["tag"],
          width: width,
        );
      },
    );
  }

  Widget _buildLastJoinedList(double width) {
    // You can customize this to show different data for Last Joined
    // For now, we'll use the same data with a different arrangement
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: libraries.length,
      itemBuilder: (context, index) {
        // Reverse the order for demonstration
        final lib = libraries[libraries.length - 1 - index];
        return LibraryCard(
          name: lib["name"],
          rating: lib["rating"],
          reviews: lib["reviews"],
          students: lib["students"],
          fee: lib["fee"],
          tag: "Joined", // Change the tag for Last Joined
          width: width,
        );
      },
    );
  }
}

class LibraryCard extends StatelessWidget {
  final String name;
  final double rating;
  final int reviews;
  final int students;
  final int fee;
  final String tag;
  final double width;

  const LibraryCard({
    super.key,
    required this.name,
    required this.rating,
    required this.reviews,
    required this.students,
    required this.fee,
    required this.tag,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Color(0xFF6b7280)),
      ),
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Placeholder
            Container(
              height: width * 0.4,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text(
                  "Library Image",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: DarkColor.green.withOpacity(0.1),
                    border: Border.all(color: DarkColor.green),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(color: DarkColor.green, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 18),
                const SizedBox(width: 4),
                Text(
                  "$rating/5.0",
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(width: 8),
                Text(
                  "• $reviews reviews",
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "$students Students Enrolled",
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: DarkColor.primary),
                    color: Colors.white.withOpacity(0.05),
                  ),
                  child: Row(
                    children: [
                      Text(
                        "\$$fee",
                        style: const TextStyle(
                          color: DarkColor.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        "/month",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
