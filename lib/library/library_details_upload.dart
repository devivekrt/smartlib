import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:smartlib/theme/theme.dart';
import 'package:smartlib/widgets/input_field.dart';
import 'package:smartlib/widgets/next_button.dart';
import 'package:smartlib/widgets/solid_button.dart';

import '../models/library_model.dart';
import '../librarian/location_access_screen.dart';

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
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  final _landMarkController = TextEditingController();

  // For shifts - using controllers for each field
  final List<TextEditingController> _shiftNameControllers = [TextEditingController()];
  final List<TextEditingController> _shiftStartTimeControllers = [TextEditingController()];
  final List<TextEditingController> _shiftEndTimeControllers = [TextEditingController()];
  final List<TextEditingController> _shiftFeeControllers = [TextEditingController()];

  // Predefined shift keys
  final List<String> _shiftKeys = ['morning'];

  final List<TextEditingController> _rulesControllers = [
    TextEditingController(),
  ];

  // Only predefined utilities
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

  DateTime _selectedDate = DateTime.now().subtract(
    const Duration(days: 365 * 20),
  );

  // Library type: 'self_study' or 'book_study'
  String? _selectedLibraryType;

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

  // Time picker for shift start and end times
  Future<void> _selectTime(BuildContext context, TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
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

    if (picked != null) {
      // Format the time as 'HH:MM'
      final String hour = picked.hour.toString().padLeft(2, '0');
      final String minute = picked.minute.toString().padLeft(2, '0');
      controller.text = '$hour:$minute';
    }
  }

  // Add a new shift with controllers
  void _addShift() {
    setState(() {
      _shiftNameControllers.add(TextEditingController());
      _shiftStartTimeControllers.add(TextEditingController());
      _shiftEndTimeControllers.add(TextEditingController());
      _shiftFeeControllers.add(TextEditingController());

      // Add a default shift key
      if (_shiftKeys.length == 1) {
        _shiftKeys.add('afternoon');
      } else if (_shiftKeys.length == 2) {
        _shiftKeys.add('evening');
      } else {
        _shiftKeys.add('shift_${_shiftKeys.length + 1}');
      }
    });
  }

  // Remove a shift with its controllers
  void _removeShift(int index) {
    setState(() {
      if (_shiftNameControllers.length > 1) {
        _shiftNameControllers.removeAt(index);
        _shiftStartTimeControllers.removeAt(index);
        _shiftEndTimeControllers.removeAt(index);
        _shiftFeeControllers.removeAt(index);
        _shiftKeys.removeAt(index);
      }
    });
  }

  void _toggleUtility(LibraryUtility utility) {
    setState(() {
      utility.isSelected = !utility.isSelected;
    });
  }

  // Calculate lowest fee across all shift controllers
  int? _calculateLowestFee() {
    int? lowest;

    for (var controller in _shiftFeeControllers) {
      if (controller.text.isNotEmpty) {
        int? fee = int.tryParse(controller.text);
        if (fee != null) {
          if (lowest == null || fee < lowest) {
            lowest = fee;
          }
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
    if (_currentPage == 2 && !_validateAdditionalInfo()) {
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

  bool _validateBasicInfo() {
    if (_libraryNameController.text.isEmpty) {
      _showError("Please enter library name");
      return false;
    }
    if (_ownerNameController.text.isEmpty) {
      _showError("Please enter owner name");
      return false;
    }
    if (_selectedLibraryType == null) {
      _showError("Please select library type");
      return false;
    }
    if (_seatsController.text.isEmpty) {
      _showError("Please enter total number of seats");
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

  bool _validateAdditionalInfo() {
    if (_descriptionController.text.isEmpty) {
      _showError("Please enter a library description");
      return false;
    }

    // Validate shifts
    for (int i = 0; i < _shiftNameControllers.length; i++) {
      if (_shiftNameControllers[i].text.isEmpty) {
        _showError("Please enter a name for shift ${i+1}");
        return false;
      }

      if (_shiftStartTimeControllers[i].text.isEmpty) {
        _showError("Please enter a start time for ${_shiftNameControllers[i].text}");
        return false;
      }

      if (_shiftEndTimeControllers[i].text.isEmpty) {
        _showError("Please enter an end time for ${_shiftNameControllers[i].text}");
        return false;
      }

      if (_shiftFeeControllers[i].text.isEmpty) {
        _showError("Please enter a fee for ${_shiftNameControllers[i].text}");
        return false;
      }
    }

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

      // Build shifts map
      Map<String, dynamic> shiftsMap = {};
      for (int i = 0; i < _shiftNameControllers.length; i++) {
        shiftsMap[_shiftKeys[i]] = {
          'shiftName': _shiftNameControllers[i].text.trim(),
          'shiftStartTime': _shiftStartTimeControllers[i].text.trim(),
          'shiftEndTime': _shiftEndTimeControllers[i].text.trim(),
          'shiftFee': int.tryParse(_shiftFeeControllers[i].text.trim()) ?? 0,
        };
      }

      // Calculate lowest fee
      final lowFee = _calculateLowestFee();

      // Get rules list
      final rules = _rulesControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      // Create library model with data from this page
      final libraryModel = LibraryModel(
        librarianId: widget.librarianId,
        libraryName: _libraryNameController.text.trim(),
        establishedDate: '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
        ownerName: _ownerNameController.text.trim(),
        totalSeats: int.tryParse(_seatsController.text) ?? 0,
        availableSeats: int.tryParse(_seatsController.text) ?? 0, // Initially all seats available
        description: _descriptionController.text.trim(),
        libraryType: _selectedLibraryType,
        rules: rules,
        contactInfo: contactInfo,
        address: address,
        shifts: shiftsMap,  // Using the new shifts map
        lowFee: lowFee,
        utilities: selectedUtilities,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LocationAccessScreen(libraryModel: libraryModel),
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
              const Gap(12),
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
              const Gap(12),
              // Library Type Selection
              const Text("Library Type", style: TextStyle(color: Colors.white70)),
              const Gap(8),
              Row(
                children: [
                  Expanded(
                    child: _buildLibraryTypeRadio(
                      value: 'self_study',
                      label: 'Self Study',
                      icon: Icons.menu_book,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildLibraryTypeRadio(
                      value: 'book_study',
                      label: 'Book Study',
                      icon: Icons.book,
                    ),
                  ),
                ],
              ),
              const Gap(12),
              const Text("Established Date", style: TextStyle(color: Colors.white70)),
              const Gap(8),
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
              const Gap(12),
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

  Widget _buildLibraryTypeRadio({required String value, required String label, required IconData icon}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLibraryType = value;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: _selectedLibraryType == value ? DarkColor.highlightColor.withOpacity(0.2) : DarkColor.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _selectedLibraryType == value ? DarkColor.highlightColor : Colors.grey[700]!,
            width: _selectedLibraryType == value ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _selectedLibraryType == value ? DarkColor.highlightColor : Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: _selectedLibraryType == value ? Colors.white : Colors.white70,
                fontWeight: _selectedLibraryType == value ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            if (_selectedLibraryType == value)
              Icon(Icons.check_circle, size: 16, color: DarkColor.highlightColor),
          ],
        ),
      ),
    );
  }

  // Page 2: Contact Information
  Widget _buildContactInfoPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
              const Gap(12),
              InputField(
                controller: _emailController,
                labelText: 'Email (Optional)',
                prefixIcon: Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        const Gap(20),
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
              const Gap(12),
              InputField(
                controller: _cityController,
                labelText: 'City',
                prefixIcon: Icons.location_city,
              ),
              const Gap(12),
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
              const Gap(12),
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
        const Gap(20),
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
            ],
          ),
        ),
        const Gap(20),
        _buildSectionCard(
          "Operating Shifts",
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._shiftNameControllers.asMap().entries.map((entry) {
                final index = entry.key;
                final nameController = entry.value;
                final startTimeController = _shiftStartTimeControllers[index];
                final endTimeController = _shiftEndTimeControllers[index];
                final feeController = _shiftFeeControllers[index];

                // Default shift names for help text
                String shiftHint = "";
                if (index == 0) shiftHint = "e.g. Morning";
                else if (index == 1) shiftHint = "e.g. Afternoon";
                else if (index == 2) shiftHint = "e.g. Evening";

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
                          if (_shiftNameControllers.length > 1)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeShift(index),
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                            ),
                        ],
                      ),
                      const Gap(8),

                      // Shift name field
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Shift Name',
                          hintText: shiftHint,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const Gap(8),

                      Row(
                        children: [
                          // Start time field with time picker
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _selectTime(context, startTimeController),
                              child: AbsorbPointer(
                                child: TextField(
                                  controller: startTimeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Start Time',
                                    hintText: '08:00',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    suffixIcon: Icon(Icons.access_time),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Gap(8),
                          // End time field with time picker
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _selectTime(context, endTimeController),
                              child: AbsorbPointer(
                                child: TextField(
                                  controller: endTimeController,
                                  decoration: const InputDecoration(
                                    labelText: 'End Time',
                                    hintText: '12:00',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    suffixIcon: Icon(Icons.access_time),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Gap(8),
                      // Fee field
                      TextField(
                        controller: feeController,
                        decoration: const InputDecoration(
                          labelText: 'Fee (₹)',
                          hintText: '50',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          prefixIcon: Icon(Icons.currency_rupee),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                );
              }).toList(),

              // Add shift button
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
        const Gap(20),
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
                      Icon(Icons.circle, size: 8, color: hasText ? Colors.green : Colors.grey),
                      const Gap(8),
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
          color: utility.isSelected
              ? DarkColor.highlightColor.withOpacity(0.2)
              : DarkColor.cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: utility.isSelected ? DarkColor.highlightColor : Colors.grey[700]!,
            width: utility.isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              utility.icon,
              size: 28,
              color: utility.isSelected ? DarkColor.highlightColor : Colors.white70,
            ),
            Gap(8),
            Text(
              utility.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: utility.isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: utility.isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 5),
            if (utility.isSelected)
              Icon(Icons.check_circle, size: 16, color: DarkColor.highlightColor),
          ],
        ),
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

    // Dispose all shift controllers
    for (var controller in _shiftNameControllers) {
      controller.dispose();
    }
    for (var controller in _shiftStartTimeControllers) {
      controller.dispose();
    }
    for (var controller in _shiftEndTimeControllers) {
      controller.dispose();
    }
    for (var controller in _shiftFeeControllers) {
      controller.dispose();
    }

    // Dispose rule controllers
    for (var controller in _rulesControllers) {
      controller.dispose();
    }

    super.dispose();
  }
}