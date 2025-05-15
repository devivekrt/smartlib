import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:smartlib/widgets/solid_button.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile and Greeting
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: AssetImage('assets/profile.jpg'), // or NetworkImage(...)
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Good Morning,", style: TextStyle(fontSize: 14, )),
                          Text("Vivek 👋", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),

                  // Notification Icon
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.notifications_active, color: Colors.white70),
                  ),
                ],
              ),

              //student card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 6,
              child: Container(

                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xff1940CC), Color(0xff4169E1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// Header with name & icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(Icons.account_balance_rounded, color: Colors.white, size: 30),
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white,
                          child: IconButton(
                            onPressed: () {},

                            icon: Icon(Icons.refresh, color: Color(0xff1940CC)),
                          ),
                        ),
                      ],
                    ),

                    Gap(12),

                    /// Info rows
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow("📚 Library:", "Central Public Library"),
                        _buildInfoRow("📍 Location:", "Downtown Avenue"),
                        /// Occupancy Progress Bar
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Occupancy", style: TextStyle(color: Colors.white70)),
                            SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: 0.65,
                              minHeight: 6,
                              backgroundColor: Colors.white24,
                              valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                            ),
                            SizedBox(height: 4),
                            Text("87 of 134 Seats Filled",
                                style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),

                    SizedBox(height: 12),
                    Divider(color: Colors.white54),

                    /// Fee and button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Monthly Fee",
                                style: TextStyle(color: Colors.white70, fontSize: 13)),
                            Text("\$500",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        SolidButton(text: "Pay Now", onPressed: (){},buttonColor: Colors.white,),

                      ],
                    ),

                    SizedBox(height: 10),

                    /// Due date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.access_time, color: Colors.white70, size: 16),
                        SizedBox(width: 6),
                        Text("Due: 01/04/2025",
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ),



          Gap(20),
              // Ads Banner Placeholder
              Container(
                height: height / 5,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                    child: Text("Ads Banner",
                        style: TextStyle(color: Colors.white, fontSize: 16))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Helper widget
Widget _buildInfoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Text(label,
            style: TextStyle(color: Colors.white70, fontSize: 14)),
        Gap(5),
        Text(value,
            style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}