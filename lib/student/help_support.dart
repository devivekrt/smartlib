import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

import 'package:url_launcher/url_launcher.dart';

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({Key? key}) : super(key: key);

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  bool _isLoading = false; // Changed from true to false since we're not actually loading anything
  String _appVersion = "1.0.0"; // Added default version
  String _buildNumber = "1"; // Added default build number
  final String _supportEmail = "devivekrt@gmail.com";
  final String _whatsappNumber = "+917634983125"; // Replace with actual number

  // List of FAQs
  final List<Map<String, String>> _faqs = [
    {
      'question': 'How do I book a seat?',
      'answer':
      'To book a seat, go to the Library Marketplace, select your preferred library, and tap on "Book a Seat". Follow the prompts to select your seat and shift, then complete the booking process by making the payment if required.',
    },
    {
      'question': 'How do I check in to a library?',
      'answer':
      'You can check in to a library by scanning the QR code displayed at the library entrance. Tap the QR code scanner button in the center of the bottom navigation bar and scan the library\'s QR code.',
    },
    {
      'question': 'How do I check out from a library?',
      'answer':
      'To check out, you can either scan the same QR code that you used to check in, or go to the "My Bookings" section and tap on "Check Out" for your active booking.',
    },
    {
      'question': 'Can I book seats in multiple libraries simultaneously?',
      'answer':
      'No, you can only have an active booking in one library at a time. You need to check out from your current library before booking a seat in another one.',
    },
    {
      'question': 'How do I cancel a booking?',
      'answer':
      'You can cancel a booking by going to "My Bookings", selecting the booking you wish to cancel, and tapping on the "Cancel Booking" button. Please note that cancellation policies may apply depending on the library.',
    },
    {
      'question': 'How do refunds work?',
      'answer':
      'Refund policies vary by library. Generally, if you cancel a booking before it starts, you may be eligible for a full or partial refund. Check the specific library\'s policies for detailed information.',
    },
    {
      'question': 'How do I add a library to favorites?',
      'answer':
      'When viewing a library\'s details, tap the heart icon in the top right corner to add it to your favorites. You can view all your favorite libraries in the Favorites section.',
    },
    {
      'question':
      'I\'m having technical issues with the app. What should I do?',
      'answer':
      'First, try restarting the app. If the issue persists, check that your app is updated to the latest version. If problems continue, contact our support team through the "Contact Support" option on this page.',
    },
  ];

  @override
  void initState() {
    super.initState();

  }



// Then replace your methods with these implementations:

  Future<void> _contactViaEmail() async {
    try {
      // Show message with copy functionality
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Contact us at: $_supportEmail'),
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'COPY EMAIL',
              onPressed: () {
                // Copy email to clipboard using Flutter's built-in Clipboard
                Clipboard.setData(ClipboardData(text: _supportEmail)).then((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Email address copied to clipboard'),
                        duration: Duration(seconds: 2),
                      )
                  );
                });
              },
            ),
          )
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not prepare email: $e'))
      );
    }
  }

  Future<void> _contactViaWhatsapp() async {
    try {
      // Show message with copy functionality
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Contact us on WhatsApp: $_whatsappNumber'),
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'COPY NUMBER',
              onPressed: () {
                // Copy WhatsApp number to clipboard using Flutter's built-in Clipboard
                Clipboard.setData(ClipboardData(text: _whatsappNumber)).then((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('WhatsApp number copied to clipboard'),
                        duration: Duration(seconds: 2),
                      )
                  );
                });
              },
            ),
          )
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not prepare WhatsApp: $e'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color accentColor = Color(0xff1940CC);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Help & Support',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body:
      _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, Color(0xFF3358FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.support_agent,
                    size: 64,
                    color: Colors.white,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'How can we help you?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Find answers or contact our support team',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Contact Support Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact Support',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),

                  // Contact options
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).cardColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildContactOptionTile(
                          icon: Icons.email_outlined,
                          title: 'Email Support',
                          subtitle: _supportEmail,
                          onTap: _contactViaEmail,
                          color: Colors.green,
                        ),
                        Divider(height: 1),
                        _buildContactOptionTile(
                          icon: Icons.perm_contact_calendar_sharp,
                          title: 'WhatsApp Support',
                          subtitle: 'Tap to message us on WhatsApp',
                          onTap: _contactViaWhatsapp,
                          color: Color(0xFF25D366), // WhatsApp green
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // FAQs Section
                  Text(
                    'Frequently Asked Questions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),

                  // FAQ accordions
                  ..._buildFaqItems(accentColor),

                  SizedBox(height: 24),

                  // App information card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color:
                      isDarkMode
                          ? Colors.blueGrey.shade900
                          : Colors.blue.shade50,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          backgroundColor: accentColor.withOpacity(0.1),
                          radius: 30,
                          child: Icon(
                            Icons.book,
                            color: accentColor,
                            size: 30,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'SmartLib',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Version $_appVersion (Build $_buildNumber)',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.color
                                ?.withOpacity(0.7),
                          ),
                        ),
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                // Implement check for updates functionality
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Checking for updates...',
                                    ),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: accentColor,
                                side: BorderSide(color: accentColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    20,
                                  ),
                                ),
                              ),
                              child: Text('Check for Updates'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 40), // Bottom padding
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFaqItems(Color accentColor) {
    return _faqs.map((faq) {
      return Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
          expandedAlignment: Alignment.topLeft,
          title: Text(
            faq['question']!,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          leading: Icon(Icons.help_outline_rounded, color: accentColor),
          children: [
            Text(faq['answer']!, style: TextStyle(fontSize: 14, height: 1.5)),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildContactOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 13)),
      trailing: Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}