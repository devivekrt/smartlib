import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TermsPoliciesPage extends StatefulWidget {
  const TermsPoliciesPage({Key? key}) : super(key: key);

  @override
  State<TermsPoliciesPage> createState() => _TermsPoliciesPageState();
}

class _TermsPoliciesPageState extends State<TermsPoliciesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String _termsText = '';
  String _privacyText = '';
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadPolicyTexts();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPolicyTexts() async {
    try {
      // Simulate loading delay for a smoother experience
      await Future.delayed(Duration(milliseconds: 500));

      // Load the policy texts from assets
      final termsText = await rootBundle
          .loadString('assets/terms_of_service.txt')
          .catchError((_) => _getSampleTermsText());
      final privacyText = await rootBundle
          .loadString('assets/privacy_policy.txt')
          .catchError((_) => _getSamplePrivacyText());

      if (mounted) {
        setState(() {
          _termsText = termsText;
          _privacyText = privacyText;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading policy texts: $e');
      if (mounted) {
        setState(() {
          _termsText = _getSampleTermsText();
          _privacyText = _getSamplePrivacyText();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color accentColor = Color(0xff1940CC);
    final selectedTabColor = accentColor;
    final unselectedTabColor =
    Theme.of(context).textTheme.titleMedium?.color?.withOpacity(0.5);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 180.0,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: isDarkMode ? Colors.black : accentColor,
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: Text(
                  'Terms & Policies',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    shadows: [
                      Shadow(
                        blurRadius: 4.0,
                        color: Colors.black.withOpacity(0.3),
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        accentColor,
                        Color(0xFF0028A8),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Abstract pattern overlay
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.1,
                          child: CustomPaint(
                            painter: AbstractPatternPainter(),
                          ),
                        ),
                      ),

                      // Content overlay
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(height: 30),
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _selectedTabIndex == 0
                                    ? Icons.gavel
                                    : Icons.shield,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(48),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.label,
                    indicatorColor: accentColor,
                    labelColor: selectedTabColor,
                    unselectedLabelColor: unselectedTabColor,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      color: accentColor.withOpacity(0.1),
                    ),
                    tabs: [
                      Tab(
                        icon: Icon(Icons.gavel),
                        text: 'Terms of Service',
                      ),
                      Tab(
                        icon: Icon(Icons.privacy_tip),
                        text: 'Privacy Policy',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: _isLoading
            ? _buildLoadingView(accentColor)
            : TabBarView(
          controller: _tabController,
          children: [
            _buildTermsTab(),
            _buildPrivacyTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView(Color accentColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 60,
            width: 60,
            child: CircularProgressIndicator(
              color: accentColor,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Loading content...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsTab() {
    final lastUpdated = "July 01, 2023"; // Replace with actual date
    final accentColor = Color(0xff1940CC);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Last updated info
          Container(
            margin: EdgeInsets.symmetric(vertical: 16),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accentColor.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.update,
                      size: 20,
                      color: accentColor,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Last updated',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  lastUpdated,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),

          // Main content
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: _buildFormattedTermsText(),
          ),

          SizedBox(height: 24),

          // Contact info with animation
          AnimatedContainer(
            duration: Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor.withOpacity(0.8),
                  accentColor,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.3),
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.support_agent,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Questions about our Terms?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  'If you have any questions about our Terms of Service, please contact us at legal@smartlib.com',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    // Implement email action
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Opening email client...')));
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'Contact Legal Team',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPrivacyTab() {
    final lastUpdated = "July 01, 2023"; // Replace with actual date
    final accentColor = Color(0xff1940CC);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Last updated info
          Container(
            margin: EdgeInsets.symmetric(vertical: 16),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accentColor.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.update,
                      size: 20,
                      color: accentColor,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Last updated',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  lastUpdated,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),

          // Main content
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: _buildFormattedPrivacyText(),
          ),

          SizedBox(height: 24),

          // Data controls section with enhanced design
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Theme.of(context).cardColor,
              border: Border.all(
                color: accentColor.withOpacity(0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 15,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.settings_outlined,
                        color: accentColor,
                      ),
                    ),
                    SizedBox(width: 16),
                    Text(
                      'Your Privacy Controls',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                _buildEnhancedPrivacyControl(
                  'Delete My Data',
                  'Request deletion of your personal data',
                  Icons.delete_forever,
                  Colors.red.shade700,
                      () {
                    _showDataDeletionDialog();
                  },
                ),
                SizedBox(height: 12),
                _buildEnhancedPrivacyControl(
                  'Download My Data',
                  'Request a copy of your personal data',
                  Icons.cloud_download,
                  Colors.green.shade700,
                      () {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'Data download request submitted. You will be notified when your data is ready to download.')));
                  },
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Contact info with animation
          AnimatedContainer(
            duration: Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor.withOpacity(0.8),
                  accentColor,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.3),
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.support_agent,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Questions about our Privacy Policy?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  'If you have any questions about our Privacy Policy or how we handle your data, please contact our Data Protection Officer at privacy@smartlib.com',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    // Implement email action
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Opening email client...')));
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'Contact Privacy Team',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 40),
        ],
      ),
    );
  }

  // Custom formatted text widget instead of Markdown
  Widget _buildFormattedTermsText() {
    final List<String> lines = _termsText.split('\n');
    final List<Widget> formattedContent = [];

    String currentSection = '';
    List<String> currentSectionContent = [];
    Color accentColor = Color(0xff1940CC);

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];

      if (line.startsWith('# ')) {
        // Add previous section if it exists
        if (currentSection.isNotEmpty) {
          formattedContent.add(_buildTextSection(
              currentSection, currentSectionContent, accentColor));
          currentSectionContent = [];
        }

        // This is a title (h1)
        formattedContent.add(
          Padding(
            padding: EdgeInsets.only(top: 16.0, bottom: 12.0),
            child: Text(
              line.substring(2),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
          ),
        );
      } else if (line.startsWith('## ')) {
        // Add previous section if it exists
        if (currentSection.isNotEmpty) {
          formattedContent.add(_buildTextSection(
              currentSection, currentSectionContent, accentColor));
          currentSectionContent = [];
        }

        // This is a section header (h2)
        currentSection = line.substring(3);
      } else if (line.isNotEmpty) {
        // Regular text
        currentSectionContent.add(line);
      } else if (currentSectionContent.isNotEmpty) {
        // Empty line, but we have content - add paragraph spacing
        currentSectionContent.add('');
      }
    }

    // Add the last section
    if (currentSection.isNotEmpty) {
      formattedContent.add(
          _buildTextSection(currentSection, currentSectionContent, accentColor));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: formattedContent,
    );
  }

  Widget _buildFormattedPrivacyText() {
    final List<String> lines = _privacyText.split('\n');
    final List<Widget> formattedContent = [];

    String currentSection = '';
    List<String> currentSectionContent = [];
    Color accentColor = Color(0xff1940CC);

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];

      if (line.startsWith('# ')) {
        // Add previous section if it exists
        if (currentSection.isNotEmpty) {
          formattedContent.add(_buildTextSection(
              currentSection, currentSectionContent, accentColor));
          currentSectionContent = [];
        }

        // This is a title (h1)
        formattedContent.add(
          Padding(
            padding: EdgeInsets.only(top: 16.0, bottom: 12.0),
            child: Text(
              line.substring(2),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
          ),
        );
      } else if (line.startsWith('## ')) {
        // Add previous section if it exists
        if (currentSection.isNotEmpty) {
          formattedContent.add(_buildTextSection(
              currentSection, currentSectionContent, accentColor));
          currentSectionContent = [];
        }

        // This is a section header (h2)
        currentSection = line.substring(3);
      } else if (line.startsWith('### ')) {
        // Add special handling for h3 headers
        currentSectionContent.add('');
        currentSectionContent.add('**${line.substring(4)}**');
      } else if (line.startsWith('- ')) {
        // Handle bullet points
        currentSectionContent.add(line);
      } else if (line.isNotEmpty) {
        // Regular text
        currentSectionContent.add(line);
      } else if (currentSectionContent.isNotEmpty) {
        // Empty line, but we have content - add paragraph spacing
        currentSectionContent.add('');
      }
    }

    // Add the last section
    if (currentSection.isNotEmpty) {
      formattedContent.add(
          _buildTextSection(currentSection, currentSectionContent, accentColor));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: formattedContent,
    );
  }

  Widget _buildTextSection(
      String title, List<String> content, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Padding(
          padding: EdgeInsets.only(top: 24.0, bottom: 10.0),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ),
        // Section content
        ...content.map((line) {
          if (line.isEmpty) {
            return SizedBox(height: 8); // Space between paragraphs
          }

          if (line.startsWith('- ')) {
            // This is a bullet point
            return Padding(
              padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(fontSize: 14, height: 1.6)),
                  Expanded(
                    child: Text(
                      line.substring(2),
                      style: TextStyle(fontSize: 14, height: 1.6),
                    ),
                  ),
                ],
              ),
            );
          } else if (line.startsWith('**') && line.endsWith('**')) {
            // This is bold text (typically h3 headers)
            return Padding(
              padding: EdgeInsets.only(top: 12.0, bottom: 8.0),
              child: Text(
                line.substring(2, line.length - 2),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                ),
              ),
            );
          } else {
            // Regular paragraph
            return Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text(
                line,
                style: TextStyle(fontSize: 14, height: 1.6),
              ),
            );
          }
        }).toList(),
      ],
    );
  }

  Widget _buildEnhancedPrivacyControl(
      String title,
      String description,
      IconData icon,
      Color iconColor,
      VoidCallback onTap,
      ) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey.shade800.withOpacity(0.3)
            : Colors.grey.shade50,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.color
                            ?.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, size: 24, color: iconColor),
            ],
          ),
        ),
      ),
    );
  }

  void _showDataDeletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            SizedBox(width: 10),
            Text(
              'Delete Your Data',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to request deletion of all your personal data?',
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red.shade800, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. Your account will be deactivated and scheduled for deletion.',
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.delete_forever, size: 18),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () {
              // Handle data deletion request
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      'Data deletion request submitted. You will receive an email with further instructions.')));
            },
            label: Text(
              'Delete My Data',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Sample texts if the asset files are not available
  String _getSampleTermsText() {
    return '''
# Terms of Service for SmartLib

## 1. Acceptance of Terms

By accessing or using the SmartLib mobile application ("the App"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, please do not use the App.

## 2. Description of Service

SmartLib provides a platform for users to find, book, and check in/out of library seats and facilities. Users can discover libraries, view availability, make bookings, and manage their library visits.

## 3. User Accounts

3.1 You must create an account to use certain features of the App.
3.2 You are responsible for maintaining the confidentiality of your account credentials.
3.3 You are responsible for all activities that occur under your account.
3.4 You must provide accurate, current, and complete information during registration.
3.5 We reserve the right to suspend or terminate accounts that violate these Terms.

## 4. Booking and Payment

4.1 All bookings are subject to availability and approval by the respective libraries.
4.2 Payment methods and fees vary by library and are clearly displayed before confirming a booking.
4.3 Refund policies are determined by each individual library and may vary.
4.4 Users agree to pay all applicable fees associated with their bookings.

## 5. User Conduct

Users agree not to:
5.1 Use the App for any illegal purpose or in violation of any laws.
5.2 Interfere with or disrupt the operation of the App or servers.
5.3 Attempt to gain unauthorized access to any part of the App.
5.4 Use the App to transmit harmful code or materials.
5.5 Impersonate another person or entity.
5.6 Create multiple accounts for abusive purposes.

## 6. Intellectual Property

6.1 The App and its original content, features, and functionality are owned by SmartLib and are protected by copyright, trademark, and other intellectual property laws.
6.2 Users may not copy, modify, distribute, or reproduce any part of the App without prior written permission.

## 7. Limitation of Liability

7.1 SmartLib is provided "as is" without warranties of any kind.
7.2 We are not liable for any damages arising from the use of the App.
7.3 We do not guarantee that the App will be error-free or uninterrupted.

## 8. Changes to Terms

We reserve the right to modify these Terms at any time. We will notify users of significant changes via the App or email.

## 9. Termination

We may terminate or suspend access to the App immediately, without prior notice, for conduct that violates these Terms.

## 10. Governing Law

These Terms shall be governed by the laws of India, without regard to its conflict of law provisions.
''';
  }

  String _getSamplePrivacyText() {
    return '''
# Privacy Policy for SmartLib

## 1. Introduction

SmartLib ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.

## 2. Information We Collect

### Personal Information
- Name, email address, phone number, and profile picture
- Account login credentials
- Payment information (processed through secure third-party payment processors)
- Location data (when you grant permission)

### Usage Information
- App usage statistics and interactions
- Device information (device type, operating system)
- Log data and analytics

## 3. How We Use Your Information

We use the information we collect to:
- Provide, maintain, and improve our services
- Process bookings and payments
- Communicate with you about your account and bookings
- Send updates, security alerts, and support messages
- Prevent fraud and abuse
- Personalize your experience
- Analyze usage patterns to improve the App

## 4. Data Sharing and Disclosure

We may share your information with:
- Libraries where you make bookings (only relevant booking details)
- Third-party service providers who assist in operating the App
- Law enforcement when required by law
- Other parties with your explicit consent

We do not sell your personal information to third parties.

## 5. Data Security

We implement appropriate security measures to protect your personal information from unauthorized access, alteration, disclosure, or destruction. However, no method of transmission over the internet or electronic storage is 100% secure.

## 6. Your Choices and Rights

You have the right to:
- Access your personal data
- Correct inaccurate data
- Delete your data (subject to certain limitations)
- Restrict or object to certain processing activities
- Download a copy of your data

To exercise these rights, contact us at privacy@smartlib.com.

## 7. Children's Privacy

The App is not intended for children under 13. We do not knowingly collect information from children under 13.

## 8. Changes to This Privacy Policy

We may update our Privacy Policy from time to time. We will notify you of significant changes via the App or email.

## 9. Contact Us

If you have questions or concerns about this Privacy Policy, please contact us at:
- Email: privacy@smartlib.com
- Address: SmartLib Headquarters, Tech Park, Bangalore 560001, India
''';
  }
}

// Abstract pattern painter for a nicer header background
class AbstractPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final random = DateTime.now().microsecondsSinceEpoch;

    // Draw some random lines and circles
    for (int i = 0; i < 20; i++) {
      final x = (random % (i + 1) * 7) % size.width;
      final y = (random % (i + 3) * 11) % size.height;

      // Draw circles
      canvas.drawCircle(
        Offset(x, y),
        (i * 5) % 40 + 5,
        paint,
      );

      // Draw lines
      if (i % 3 == 0) {
        canvas.drawLine(
          Offset(x, y),
          Offset((x + 100) % size.width, (y + 80) % size.height),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}