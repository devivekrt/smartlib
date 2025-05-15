import 'package:flutter/material.dart';

class MarketPlace extends StatefulWidget {
  const MarketPlace({super.key});

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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Library Marketplace", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView.builder(
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
        ),
      ),
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
      shape: OutlineInputBorder(borderRadius: BorderRadius.circular(16),borderSide: BorderSide(color: Color(0xFF6b7280))),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    border: Border.all(color: Colors.amber),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(color: Colors.amber, fontSize: 12),
                  ),
                )
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber),
                    color: Colors.white.withOpacity(0.05),
                  ),
                  child: Row(
                    children: [
                      Text(
                        "\$$fee",
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        "/month",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      )
                    ],
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
