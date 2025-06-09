import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:smartlib/theme/theme.dart';
import 'package:smartlib/widgets/input_field.dart';
import 'package:smartlib/widgets/solid_button.dart';
import '../logic/string.dart';
import '../models/library_model.dart';


class LibraryEditScreen extends StatefulWidget {
  final String librarianId;
  final String libraryId;

  const LibraryEditScreen({
    super.key,
    required this.librarianId,
    required this.libraryId,
  });

  @override
  State<LibraryEditScreen> createState() => _LibraryEditScreenState();
}

class _LibraryEditScreenState extends State<LibraryEditScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  LibraryModel? _library;

  // Form controllers
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

  // For shifts
  late List<ShiftModel> _shifts;

  late List<TextEditingController> _rulesControllers;

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
  late List<LibraryUtility> _customUtilities;
  final _customUtilityController = TextEditingController();

  late DateTime _selectedDate;

  // Current tab for editing
  int _currentTab = 0;
  final _tabTitles = [
    'Basic Info',
    'Contact & Address',
    'Utilities & Features',
    'Shifts & Rules'
  ];

  @override
  void initState() {
    super.initState();
    _shifts = [];
    _rulesControllers = [];
    _customUtilities = [];
    _selectedDate = DateTime.now().subtract(const Duration(days: 365 * 20));
    _fetchLibraryData();
  }

  Future<void> _fetchLibraryData() async {
    try {
      // METHOD 1: Verify this library belongs to the librarian
      final managedLibrariesRef = FirebaseDatabase.instance
          .ref('${SmartLib.constPath}/users/librarians/${widget.librarianId}/managedLibraries')
          .child(widget.libraryId);

      final snapshot = await managedLibrariesRef.get();

      if (!snapshot.exists || snapshot.value != true) {
        _showError("You don't have permission to edit this library");
        Navigator.pop(context);
        return;
      }

      // Permission verified, get library data
      final libraryDoc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(widget.libraryId)
          .get();

      if (!libraryDoc.exists) {
        _showError("Library not found");
        Navigator.pop(context);
        return;
      }

      // Create library model from document
      _library = LibraryModel.fromMap(libraryDoc.data()!, libraryDoc.id);

      // Populate form controllers and state
      _populateFormFields();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading library: $e');
      _showError("Error loading library data: $e");
      Navigator.pop(context);
    }
  }

  void _populateFormFields() {
    // Basic info
    _libraryNameController.text = _library!.libraryName ?? '';
    _ownerNameController.text = _library!.ownerName ?? '';
    _seatsController.text = _library!.totalSeats?.toString() ?? '';
    _descriptionController.text = _library!.description ?? '';

    // Parse established date
    if (_library!.establishedDate != null) {
      final dateParts = _library!.establishedDate!.split('/');
      if (dateParts.length == 3) {
        try {
          final day = int.parse(dateParts[0]);
          final month = int.parse(dateParts[1]);
          final year = int.parse(dateParts[2]);
          _selectedDate = DateTime(year, month, day);
        } catch (e) {
          print('Error parsing date: $e');
        }
      }
    }

    // Contact & address
    if (_library!.contactInfo != null) {
      _phoneController.text = _library!.contactInfo!['phone'] ?? '';
      _emailController.text = _library!.contactInfo!['email'] ?? '';
    }

    if (_library!.address != null) {
      _streetController.text = _library!.address!['street'] ?? '';
      _cityController.text = _library!.address!['city'] ?? '';
      _stateController.text = _library!.address!['state'] ?? '';
      _zipController.text = _library!.address!['zipCode'] ?? '';
      _landMarkController.text = _library!.address!['landMark'] ?? '';
    }

    // Rules
    _rulesControllers.clear();
    if (_library!.rules.isNotEmpty) {
      for (String rule in _library!.rules) {
        _rulesControllers.add(TextEditingController(text: rule));
      }
    }
    if (_rulesControllers.isEmpty) {
      _rulesControllers.add(TextEditingController());
    }

    // Shifts
    _shifts = List.from(_library!.shifts);
    if (_shifts.isEmpty) {
      _shifts.add(ShiftModel());
    }

    // Utilities
    if (_library!.utilities.isNotEmpty) {
      // First reset all to not selected
      for (var utility in _utilities) {
        utility.isSelected = false;
      }

      // Mark selected utilities
      for (String utilityId in _library!.utilities) {
        // Check predefined utilities
        bool foundInPredefined = false;
        for (var utility in _utilities) {
          if (utility.id == utilityId) {
            utility.isSelected = true;
            foundInPredefined = true;
            break;
          }
        }

        // If not found in predefined, it might be custom
        if (!foundInPredefined && utilityId.startsWith('custom_')) {
          // Extract name from the utility ID
          String name = utilityId.replaceAll('custom_', '');
          if (name.contains('_')) {
            name = name.split('_').map((s) => s.isEmpty ? '' :
            '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}').join(' ');
          }

          _customUtilities.add(LibraryUtility(
            id: utilityId,
            name: name,
            icon: Icons.star,
            isSelected: true,
          ));
        }
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

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
          )
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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
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

      // Get rules from controllers
      final rules = _rulesControllers
          .map((controller) => controller.text)
          .where((text) => text.isNotEmpty)
          .toList();

      // Calculate lowest fee
      final lowFee = _calculateLowestFee();

      // Update the library in Firestore
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(widget.libraryId)
          .update({
        'libraryName': _libraryNameController.text.trim(),
        'ownerName': _ownerNameController.text.trim(),
        'establishedDate': '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
        'totalSeats': int.tryParse(_seatsController.text) ?? _library!.totalSeats,
        'description': _descriptionController.text.trim(),
        'contactInfo': contactInfo,
        'address': address,
        'rules': rules,
        'shifts': _shifts.map((shift) => shift.toMap()).toList(),
        'utilities': selectedUtilities,
        'lowFee': lowFee,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Also update realtime DB seat info if total seats changed
      final newTotalSeats = int.tryParse(_seatsController.text) ?? _library!.totalSeats;
      if (newTotalSeats != _library!.totalSeats) {
        await FirebaseDatabase.instance
            .ref('${SmartLib.constPath}/libraries/${widget.libraryId}/seats')
            .update({
          'total': newTotalSeats,
          // Keep the current available seats or reset to total if not set
          'available': _library!.availableSeats ?? newTotalSeats,
          'lastUpdated': ServerValue.timestamp,
        });
      }

      _showError("Library updated successfully");
      Navigator.pop(context, true); // Return true to indicate successful update
    } catch (e) {
      _showError("Error updating library: $e");
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _changeTab(int index) {
    setState(() {
      _currentTab = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Library', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Library image display
          if (_library!.libraryImageUrl != null)
            Container(
              width: double.infinity,
              height: 160,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(_library!.libraryImageUrl!),
                  fit: BoxFit.cover,
                ),
              ),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: FloatingActionButton.small(
                    onPressed: () {
                      // TODO: Implement image update
                      _showError("Image update coming soon");
                    },
                    backgroundColor: DarkColor.highlightColor,
                    child: Icon(Icons.edit, size: 16),
                  ),
                ),
              ),
            ),

          // Tab selector
          Container(
            height: 60,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _tabTitles.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _changeTab(index),
                  child: Container(
                    margin: EdgeInsets.only(right: 8),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _currentTab == index
                          ? DarkColor.highlightColor
                          : DarkColor.cardColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        _tabTitles[index],
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: _currentTab == index
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Tab content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: _buildTabContent(),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isLoading
          ? null
          : Padding(
        padding: const EdgeInsets.all(16),
        child: SolidButton(
          text: _isSubmitting ? "Saving..." : "Save Changes",
          onPressed: (){
            _isSubmitting ? null : _saveChanges;
          },
          width: double.infinity,
          height: 48,
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_currentTab) {
      case 0:
        return _buildBasicInfoTab();
      case 1:
        return _buildContactAddressTab();
      case 2:
        return _buildUtilitiesTab();
      case 3:
        return _buildShiftsRulesTab();
      default:
        return Container();
    }
  }

  Widget _buildBasicInfoTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          "Basic Information",
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

        const SizedBox(height: 16),

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
      ],
    );
  }

  Widget _buildContactAddressTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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

        const SizedBox(height: 16),

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

  Widget _buildUtilitiesTab() {
    return _buildSectionCard(
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
                    contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
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
              children: _customUtilities.asMap().entries.map((entry) {
                int index = entry.key;
                LibraryUtility utility = entry.value;
                return _buildCustomUtilityChip(utility, index);
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShiftsRulesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                        controller: TextEditingController(text: shift.shiftName),
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
                              controller: TextEditingController(text: shift.startTime),
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
                              controller: TextEditingController(text: shift.endTime),
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
                        controller: TextEditingController(text: shift.fee?.toString() ?? ''),
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

        const SizedBox(height: 16),

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
          color: utility.isSelected
              ? DarkColor.highlightColor.withOpacity(0.2)
              : DarkColor.cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: utility.isSelected
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
              color: utility.isSelected
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
                fontWeight: utility.isSelected ? FontWeight.bold : FontWeight.normal,
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
        color: utility.isSelected
            ? DarkColor.highlightColor.withOpacity(0.2)
            : DarkColor.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: utility.isSelected
              ? DarkColor.highlightColor
              : Colors.grey[700]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            utility.icon,
            size: 16,
            color: utility.isSelected ? DarkColor.highlightColor : Colors.white70,
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
            child: Icon(
              Icons.close,
              size: 16,
              color: Colors.red[300],
            ),
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