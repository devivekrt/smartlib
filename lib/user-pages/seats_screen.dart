import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:gap/gap.dart';
import 'package:smartlib/widgets/solid_button.dart';

class SeatsScreen extends StatefulWidget {
  const SeatsScreen({Key? key}) : super(key: key);

  @override
  State<SeatsScreen> createState() => _SeatsScreenState();
}

class _SeatsScreenState extends State<SeatsScreen> {
  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final cardColor = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;

    return SafeArea(
      child: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Book a Seat",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Gap(5),
              Text(
                "Select your preferred library and seat",
                style: TextStyle(
                  fontSize: 14,
                  color: textColor.withOpacity(0.7),
                ),
              ),
              Gap(20),

              // Library Selector
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.apartment, color: Color(0xff1940CC)),
                    SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Central University Library",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "47 seats available",
                            style: TextStyle(
                              color: textColor.withOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down, color: textColor.withOpacity(0.5)),
                  ],
                ),
              ),

              Gap(20),

              // Date & Time Selector
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: Color(0xff1940CC), size: 20),
                          SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Date",
                                style: TextStyle(
                                  color: textColor.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                "Today",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, color: Color(0xff1940CC), size: 20),
                          SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Time",
                                style: TextStyle(
                                  color: textColor.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                "2 hours",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              Gap(25),

              // Floor Plan
              Text(
                "Floor Plan - Ground Floor",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Gap(5),
              Text(
                "Select an available seat",
                style: TextStyle(
                  fontSize: 14,
                  color: textColor.withOpacity(0.7),
                ),
              ),
              Gap(15),

              // Seat Legend
              Row(
                children: [
                  _buildSeatLegendItem("Available", Colors.green, textColor),
                  SizedBox(width: 15),
                  _buildSeatLegendItem("Occupied", Colors.red, textColor),
                  SizedBox(width: 15),
                  _buildSeatLegendItem("Selected", Color(0xff1940CC), textColor),
                ],
              ),

              Gap(15),

              // Floor Map with Seats
              Container(
                height: 350,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: EdgeInsets.all(15),
                child: Stack(
                  children: [
                    // Room outlines
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: textColor.withOpacity(0.2), width: 2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),

                    // Wall sections
                    Positioned(
                      top: 0,
                      left: 100,
                      child: Container(
                        height: 70,
                        width: 2,
                        color: textColor.withOpacity(0.2),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 100,
                      child: Container(
                        height: 70,
                        width: 2,
                        color: textColor.withOpacity(0.2),
                      ),
                    ),

                    // Entrance
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                              decoration: BoxDecoration(
                                color: Color(0xff1940CC).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "ENTRANCE",
                                style: TextStyle(
                                  color: Color(0xff1940CC),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Icon(
                              CupertinoIcons.arrow_down,
                              color: Color(0xff1940CC),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Seats - Section A (Left)
                    ..._buildSeatGrid(1, 1, 4, 5, 30, 100, 10, textColor),

                    // Seats - Section B (Middle)
                    ..._buildSeatGrid(5, 1, 4, 3, 150, 100, 20, textColor),

                    // Seats - Section C (Right)
                    ..._buildSeatGrid(9, 1, 4, 5, 240, 100, 30, textColor),

                    // Center table
                    Positioned(
                      top: 150,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          height: 50,
                          width: 120,
                          decoration: BoxDecoration(
                            color: textColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: textColor.withOpacity(0.2)),
                          ),
                          child: Center(
                            child: Text(
                              "Collaborative\nTable",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: textColor.withOpacity(0.6),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Private study rooms
                    Positioned(
                      bottom: 20,
                      left: 20,
                      child: Container(
                        height: 70,
                        width: 100,
                        decoration: BoxDecoration(
                          color: textColor.withOpacity(0.05),
                          border: Border.all(color: textColor.withOpacity(0.2)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            "Private\nStudy Room 1",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: textColor.withOpacity(0.6),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: Container(
                        height: 70,
                        width: 100,
                        decoration: BoxDecoration(
                          color: textColor.withOpacity(0.05),
                          border: Border.all(color: textColor.withOpacity(0.2)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            "Private\nStudy Room 2",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: textColor.withOpacity(0.6),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Gap(25),

              // Confirm Button
              SolidButton(
                text: "Book Selected Seat",
                onPressed: () {},
                buttonColor: Color(0xff1940CC),
                width: double.infinity,
                height: 55,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Seat Legend Item
  Widget _buildSeatLegendItem(String label, Color color, Color textColor) {
    return Row(
      children: [
        Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: textColor,
          ),
        ),
      ],
    );
  }

  // Build seat grid
  List<Widget> _buildSeatGrid(
      int startRow,
      int startCol,
      int rows,
      int cols,
      double startX,
      double startY,
      int section,
      Color textColor,
      ) {
    List<Widget> seats = [];

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final seatId = "${String.fromCharCode(64 + startRow + r)}-${startCol + c}";

        // Generate some random seats as occupied (just for demonstration)
        final isOccupied = [
          "A-2", "A-4", "B-3", "B-5", "C-1", "C-4", "D-2", "D-4"
        ].contains(seatId);

        // Is this the selected seat?
        final isSelected = seatId == "B-2";

        // Seat color based on status
        final seatColor = isSelected
            ? Color(0xff1940CC)
            : (isOccupied ? Colors.red : Colors.green);

        seats.add(
          Positioned(
            top: startY + r * 40.0,
            left: startX + c * 30.0,
            child: GestureDetector(
              onTap: isOccupied ? null : () {
                // Seat selection logic would go here
              },
              child: Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  color: seatColor,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: isSelected ? Center(
                  child: Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ) : null,
              ),
            ),
          ),
        );

        // Add seat label for the first column
        if (c == 0) {
          seats.add(
            Positioned(
              top: startY + r * 40.0,
              left: startX - 20.0,
              child: Text(
                String.fromCharCode(64 + startRow + r),
                style: TextStyle(
                  fontSize: 12,
                  color: textColor.withOpacity(0.7),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }

        // Add seat number for the first row
        if (r == 0) {
          seats.add(
            Positioned(
              top: startY - 20.0,
              left: startX + c * 30.0,
              child: Text(
                (startCol + c).toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: textColor.withOpacity(0.7),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }
      }
    }

    // Add section label
    seats.add(
      Positioned(
        top: startY - 40.0,
        left: startX,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Color(0xff1940CC).withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            "Section ${section}",
            style: TextStyle(
              color: Color(0xff1940CC),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );

    return seats;
  }
}