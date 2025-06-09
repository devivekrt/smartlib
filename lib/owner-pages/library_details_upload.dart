import 'package:flutter/material.dart';
import 'package:smartlib/theme/theme.dart';
import 'package:smartlib/widgets/input_field.dart';
import 'package:smartlib/widgets/next_button.dart';
import 'package:smartlib/widgets/solid_button.dart';

import '../models/library_model.dart';
import 'location_access_screen.dart';

class LibraryDetailsUpload extends StatefulWidget {
  final String librarianId; // Pass the librarian ID from previous page
  const LibraryDetailsUpload({super.key, required this.librarianId});

  @override
  State<LibraryDetailsUpload> createState() => _LibraryDetailsUploadState();
}

class _LibraryDetailsUploadState extends State<LibraryDetailsUpload> {
  final _formKey = GlobalKey<FormState>();
  final _libraryNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _seatsController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController(); // New for contact info
  final _emailController = TextEditingController(); // New for contact info
  final _streetController = TextEditingController(); // New for address
  final _cityController = TextEditingController(); // New for address
  final _stateController = TextEditingController(); // New for address
  final _zipController = TextEditingController(); // New for address
  final _landMarkController = TextEditingController();

  // For shifts
  final List<ShiftModel> _shifts = [ShiftModel()];

  final List<TextEditingController> _rulesControllers = [
    TextEditingController(),
  ];

  // Predefined utilities list
  final List<LibraryUtility> _utilities = [
    LibraryUtility(id: 'wifi', name: 'WiFi', icon: Icons.wifi),
    LibraryUtility(id: 'cctv', name: 'CCTV', icon: Icons.videocam),
    LibraryUtility(id: 'water', name: 'RO Water', icon: Icons.water_drop),
    LibraryUtility(id: 'ac', name: 'Air Conditioning', icon: Icons.ac_unit),
    LibraryUtility(id: 'printer', name: 'Printer', icon: Icons.print),
    LibraryUtility(id: 'scanner', name: 'Scanner', icon: Icons.scanner),
    LibraryUtility(id: 'locker', name: 'Lockers', icon: Icons.lock),
    LibraryUtility(id: 'cafe', name: 'Cafeteria', icon: Icons.local_cafe),
    LibraryUtility(id: 'parking', name: 'Parking', icon: Icons.local_parking),
    LibraryUtility(id: 'charging', name: 'Charging Points', icon: Icons.power),
  ];

  // Custom utilities
  final List<LibraryUtility> _customUtilities = [];
  final _customUtilityController = TextEditingController();

  DateTime _selectedDate = DateTime.now().subtract(
    const Duration(days: 365 * 20),
  );

  // Current page in the flow - we'll use this for a multi-page form
  int _currentPage = 0;
  final int _totalPages = 3;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF2196F3),
              onPrimary: Colors.white,
              surface: Color(0xFF1E3A5F),
              onSurface: Colors.white,
            ),
            dialogTheme: DialogTheme(backgroundColor: Color(0xFF142E4F)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _addShift() {
    setState(() {
      _shifts.add(ShiftModel());
    });
  }

  void _removeShift(int index) {
    setState(() {
      if (_shifts.length > 1) {
        _shifts.removeAt(index);
      }
    });
  }

  void _toggleUtility(LibraryUtility utility) {
    setState(() {
      utility.isSelected = !utility.isSelected;
    });
  }

  void _addCustomUtility() {
    if (_customUtilityController.text.trim().isEmpty) return;

    setState(() {
      _customUtilities.add(
        LibraryUtility(
          id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
          name: _customUtilityController.text.trim(),
          icon: Icons.star,
          isSelected: true,
        ),
      );
      _customUtilityController.clear();
    });
  }

  void _removeCustomUtility(int index) {
    setState(() {
      if (index >= 0 && index < _customUtilities.length) {
        _customUtilities.removeAt(index);
      }
    });
  }

  int? _calculateLowestFee() {
    int? lowest;

    for (var shift in _shifts) {
      if (shift.fee != null) {
        if (lowest == null || shift.fee! < lowest) {
          lowest = shift.fee;
        }
      }
    }

    return lowest;
  }

  void _nextPage() {
    // Validate current page before proceeding
    if (_currentPage == 0 && !_validateBasicInfo()) {
      return;
    }

    if (_currentPage == 1 && !_validateContactInfo()) {
      return;
    }

    if (_currentPage == _totalPages - 1) {
      _proceedToNextPage(); // Last page, move to location screen
    } else {
      setState(() {
        _currentPage++;
      });
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
    } else {
      Navigator.pop(context); // Go back to previous screen
    }
  }

  bool _validateBasicInfo() {
    if (_libraryNameController.text.isEmpty) {
      _showError("Please enter library name");
      return false;
    }
    if (_ownerNameController.text.isEmpty) {
      _showError("Please enter owner name");
      return false;
    }
    return true;
  }

  bool _validateContactInfo() {
    if (_phoneController.text.isEmpty) {
      _showError("Please enter contact phone number");
      return false;
    }
    // Add more validations as needed
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _proceedToNextPage() {
    if (_formKey.currentState!.validate()) {
      // Get selected utilities
      List<String> selectedUtilities = [];

      for (var utility in _utilities) {
        if (utility.isSelected) {
          selectedUtilities.add(utility.id);
        }
      }

      for (var utility in _customUtilities) {
        if (utility.isSelected) {
          selectedUtilities.add(utility.id);
        }
      }

      // Create contact info map
      final contactInfo = {
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
      };

      // Create address map
      final address = {
        'street': _streetController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'zipCode': _zipController.text.trim(),
        'landMark': _landMarkController.text.trim(),
      };

      // Calculate lowest fee
      final lowFee = _calculateLowestFee();

      // Create library model with data from this page
      final libraryModel = LibraryModel(
        librarianId: widget.librarianId,
        libraryName: _libraryNameController.text.trim(),
        establishedDate:
            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
        ownerName: _ownerNameController.text.trim(),
        totalSeats: int.tryParse(_seatsController.text) ?? 0,
        availableSeats:
            int.tryParse(_seatsController.text) ??
            0, // Initially all seats available
        description: _descriptionController.text,
        rules:
            _rulesControllers
                .map((controller) => controller.text)
                .where((text) => text.isNotEmpty)
                .toList(),
        contactInfo: contactInfo,
        address: address,
        shifts: _shifts,
        lowFee: lowFee,
        //createdAt: DateTime.now().toIso8601String(),
        utilities: selectedUtilities, // Add the selected utilities
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => LocationAccessScreen(libraryModel: libraryModel),
        ),
      );
    }
  }

  String _getPageTitle() {
    switch (_currentPage) {
      case 0:
        return 'Basic Details';
      case 1:
        return 'Contact Information';
      case 2:
        return 'Additional Details';
      default:
        return 'Library Details';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Text(
          _getPageTitle(),
          style: const TextStyle(color: Colors.white),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress indicator
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: LinearProgressIndicator(
                  value: (_currentPage + 1) / _totalPages,
                  backgroundColor: Colors.grey[800],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    DarkColor.highlightColor,
                  ),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              // Page content based on current page
              if (_currentPage == 0) _buildBasicDetailsPage(),
              if (_currentPage == 1) _buildContactInfoPage(),
              if (_currentPage == 2) _buildAdditionalDetailsPage(),
            ],
          ),
        ),
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SizedBox(
          height: 48,
          child: NextButton(
            isEnabled: true,
            onPressed: _nextPage,
            text: _currentPage == _totalPages - 1 ? "Finish" : "Next",
          ),
        ),
      ),
    );
  }

  // Page 1: Basic Details
  Widget _buildBasicDetailsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Basic Details Card
        _buildSectionCard(
          "Basic Library Information",
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InputField(
                controller: _libraryNameController,
                labelText: 'Library Name',
                prefixIcon: Icons.local_library,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter library name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              InputField(
                controller: _ownerNameController,
                labelText: 'Library Owner Full Name',
                prefixIcon: Icons.person,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter owner name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // Established Date
              const Text(
                "Established Date",
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),

              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      Icon(Icons.calendar_today, color: Colors.white),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              InputField(
                controller: _seatsController,
                labelText: 'Total Available Seats',
                prefixIcon: Icons.event_seat,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter number of seats';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Page 2: Contact Information
  Widget _buildContactInfoPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Contact Info Card
        _buildSectionCard(
          "Contact Information",
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InputField(
                controller: _phoneController,
                labelText: 'Phone Number',
                prefixIcon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              InputField(
                controller: _emailController,
                labelText: 'Email (Optional)',
                prefixIcon: Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Library Address Card
        _buildSectionCard(
          "Library Address",
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InputField(
                controller: _streetController,
                labelText: 'Street Address',
                prefixIcon: Icons.home,
              ),
              const SizedBox(height: 12),

              InputField(
                controller: _cityController,
                labelText: 'City',
                prefixIcon: Icons.location_city,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: InputField(
                      controller: _stateController,
                      labelText: 'State',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InputField(
                      controller: _zipController,
                      labelText: 'ZIP Code',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              InputField(
                controller: _landMarkController,
                labelText: 'Location Description',
                prefixIcon: Icons.location_on,
                hintText: 'Near landmark, etc.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Page 3: Additional Details
  Widget _buildAdditionalDetailsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Library Description Card
        _buildSectionCard(
          "Description",
          InputField(
            controller: _descriptionController,
            labelText: 'Library Description',
            prefixIcon: Icons.description,
            hintText: 'Max 120 words',
            maxLines: 5,
          ),
        ),

        const SizedBox(height: 20),

        // Library Amenities Card
        _buildSectionCard(
          "Library Amenities",
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Select the amenities available at your library:",
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 16),

              // Utilities grid
              GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.1,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _utilities.length,
                itemBuilder: (context, index) {
                  return _buildUtilityTile(_utilities[index]);
                },
              ),

              SizedBox(height: 16),

              // Custom utilities section
              Text(
                "Add your own custom amenities:",
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customUtilityController,
                      decoration: InputDecoration(
                        hintText: 'Enter amenity name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  InkWell(
                    onTap: _addCustomUtility,
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: DarkColor.highlightColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.add, color: Colors.white),
                    ),
                  ),
                ],
              ),

              if (_customUtilities.isNotEmpty) ...[
                SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children:
                      _customUtilities.asMap().entries.map((entry) {
                        int index = entry.key;
                        LibraryUtility utility = entry.value;
                        return _buildCustomUtilityChip(utility, index);
                      }).toList(),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Operating Shifts Card
        _buildSectionCard(
          "Operating Shifts",
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._shifts.asMap().entries.map((entry) {
                final index = entry.key;
                final shift = entry.value;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade700),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Shift ${index + 1}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (_shifts.length > 1)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeShift(index),
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                            ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Shift details
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Shift Name (e.g. Morning, Evening)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onChanged: (value) => shift.shiftName = value,
                      ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'Start Time',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              onChanged: (value) => shift.startTime = value,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'End Time',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              onChanged: (value) => shift.endTime = value,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Fee (₹)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => shift.fee = int.tryParse(value),
                      ),
                    ],
                  ),
                );
              }).toList(),

              // Add Shift Button
              Align(
                alignment: Alignment.center,
                child: ElevatedButton.icon(
                  onPressed: _addShift,
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: const Text(
                    "Add Shift",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DarkColor.highlightColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Rules Card
        _buildSectionCard(
          "Library Rules & Information",
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._rulesControllers.asMap().entries.map((entry) {
                final index = entry.key;
                final controller = entry.value;
                final hasText = controller.text.trim().isNotEmpty;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: hasText ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InputField(
                          controller: controller,
                          labelText: '',
                          hintText: 'Enter rule/information',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                if (_rulesControllers.length > 1) {
                                  _rulesControllers.removeAt(index);
                                } else {
                                  controller.clear();
                                }
                              });
                            },
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _rulesControllers.add(TextEditingController());
                    });
                  },
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: const Text(
                    "Add Rule",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DarkColor.highlightColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUtilityTile(LibraryUtility utility) {
    return GestureDetector(
      onTap: () => _toggleUtility(utility),
      child: Container(
        decoration: BoxDecoration(
          color:
              utility.isSelected
                  ? DarkColor.highlightColor.withOpacity(0.2)
                  : DarkColor.cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                utility.isSelected
                    ? DarkColor.highlightColor
                    : Colors.grey[700]!,
            width: utility.isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              utility.icon,
              size: 28,
              color:
                  utility.isSelected
                      ? DarkColor.highlightColor
                      : Colors.white70,
            ),
            SizedBox(height: 8),
            Text(
              utility.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: utility.isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight:
                    utility.isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 5),
            if (utility.isSelected)
              Icon(
                Icons.check_circle,
                size: 16,
                color: DarkColor.highlightColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomUtilityChip(LibraryUtility utility, int index) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color:
            utility.isSelected
                ? DarkColor.highlightColor.withOpacity(0.2)
                : DarkColor.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              utility.isSelected ? DarkColor.highlightColor : Colors.grey[700]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            utility.icon,
            size: 16,
            color:
                utility.isSelected ? DarkColor.highlightColor : Colors.white70,
          ),
          SizedBox(width: 6),
          Text(
            utility.name,
            style: TextStyle(
              color: utility.isSelected ? Colors.white : Colors.white70,
            ),
          ),
          SizedBox(width: 4),
          GestureDetector(
            onTap: () => _removeCustomUtility(index),
            child: Icon(Icons.close, size: 16, color: Colors.red[300]),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, Widget content) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: DarkColor.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
          ],
          content,
        ],
      ),
    );
  }

  @override
  void dispose() {
    _libraryNameController.dispose();
    _ownerNameController.dispose();
    _landMarkController.dispose();
    _seatsController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _customUtilityController.dispose();
    for (var controller in _rulesControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
