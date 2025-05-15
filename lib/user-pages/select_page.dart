import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'Login.dart';

class SelectPage extends StatefulWidget {
  const SelectPage({super.key});

  @override
  State<SelectPage> createState() => _SelectPageState();
}

class _SelectPageState extends State<SelectPage> {
  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;
    return  Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const Text(
                "You are",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      Text(
                        "Librarian",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Gap(10),
                      GestureDetector(
                        onTap: (){
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => Login()),
                          );
                        },
                        child: Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),),

                          child: Container(
                            width: width*0.4,
                            height: height*0.3,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(colors: [Colors.blueAccent,Colors.lightBlue])
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        "Student",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 10,),
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),),
                        child: Container(
                          width: width*0.4,
                          height: height*0.3,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(colors: [Colors.deepOrangeAccent,Colors.orangeAccent])
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
             Column(
               children: [
                 const Text(
                   "Already have an account ?",
                   textAlign: TextAlign.center,
                   style: TextStyle(
                     color: Colors.white70,
                     fontSize: 14,
                     letterSpacing: 0.2,
                   ),
                 ),
                 SizedBox(height: 10,),
                 ElevatedButton(
                   onPressed: () {
                     Navigator.of(context).pop();
                   },
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.blueGrey,
                     minimumSize: Size(width*0.5, 55),
                     shape: RoundedRectangleBorder(
                       borderRadius: BorderRadius.circular(25),
                     ),
                     elevation: 5,
                   ),
                   child: const Text(
                     "Login",
                     style: TextStyle(
                       fontWeight: FontWeight.bold,
                       color: Colors.white,
                       fontSize: 16,
                     ),
                   ),
                 ),
               ],
             )

            ],
          ),
        ),
      ),
    );
  }
}
