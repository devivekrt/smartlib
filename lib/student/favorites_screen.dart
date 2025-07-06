import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartlib/data/string.dart';
import 'package:smartlib/models/library_model.dart';
import 'package:smartlib/student/library_detail_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with AutomaticKeepAliveClientMixin {
  final _database = FirebaseDatabase.instance;
  final _firestore = FirebaseFirestore.instance;

  List<String> _favoriteIds = [];
  List<LibraryModel> _favoriteLibraries = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isEmpty = false;

  StreamSubscription? _favoritesSubscription;

  @override
  bool get wantKeepAlive => true; // Keep state when navigating away

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void dispose() {
    _favoritesSubscription?.cancel();
    super.dispose();
  }

  // Load favorite library IDs from Firebase Realtime Database
  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Set up listener for favorite changes
      final favoritesRef = _database
          .ref('${SmartLib.constPath}/students/${SmartLib.userId}/favorites');

      _favoritesSubscription = favoritesRef.onValue.listen((event) async {
        // Clear previous data
        _favoriteIds = [];

        if (!event.snapshot.exists || event.snapshot.value == null) {
          setState(() {
            _isEmpty = true;
            _isLoading = false;
            _favoriteLibraries = [];
          });
          return;
        }

        // Parse favorite IDs from snapshot
        final Map<dynamic, dynamic> favorites = event.snapshot.value as Map<dynamic, dynamic>;

        List<String> ids = [];
        favorites.forEach((key, value) {
          ids.add(key.toString());
        });

        // Sort by timestamp if available
        ids.sort((a, b) {
          final timestampA = favorites[a]['timestamp'] ?? 0;
          final timestampB = favorites[b]['timestamp'] ?? 0;
          return timestampB.compareTo(timestampA); // Newest first
        });

        _favoriteIds = ids;

        // If we have favorites, load the library details
        if (_favoriteIds.isNotEmpty) {
          await _loadLibraryDetails();
        } else {
          setState(() {
            _isEmpty = true;
            _isLoading = false;
          });
        }
      }, onError: (error) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load favorites: ${error.toString()}';
          _isLoading = false;
        });
      });

    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Load details for all favorite libraries
  Future<void> _loadLibraryDetails() async {
    try {
      List<LibraryModel> libraries = [];

      // Batch query all favorite libraries
      final QuerySnapshot snapshot = await _firestore
          .collection('libraries')
          .where('id', whereIn: _favoriteIds)
          .get();

      // Sort libraries in the same order as _favoriteIds
      Map<String, DocumentSnapshot> docsMap = {};
      for (var doc in snapshot.docs) {
        docsMap[doc.id] = doc;
      }

      for (String id in _favoriteIds) {
        if (docsMap.containsKey(id)) {
          final data = docsMap[id]!.data() as Map<String, dynamic>;
          data['id'] = id;
          libraries.add(LibraryModel.fromMap(data));
        }
      }

      setState(() {
        _favoriteLibraries = libraries;
        _isEmpty = libraries.isEmpty;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Error loading library details: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Remove a library from favorites
  Future<void> _removeFavorite(String libraryId) async {
    try {
      final ref = _database
          .ref('${SmartLib.constPath}/students/${SmartLib.userId}/favorites')
          .child(libraryId);

      await ref.remove();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Removed from favorites'))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove from favorites'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Favorite Libraries',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    } else if (_hasError) {
      return _buildErrorState();
    } else if (_isEmpty) {
      return _buildEmptyState();
    } else {
      return _buildFavoritesList();
    }
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => _buildShimmerItem(),
    );
  }

  Widget _buildShimmerItem() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade800,
      highlightColor: Colors.grey.shade700,
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade300,
          ),
          SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadFavorites,
            icon: Icon(Icons.refresh),
            label: Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xff1940CC),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 80,
            color: Colors.grey.shade600,
          ),
          SizedBox(height: 24),
          Text(
            'No favorites yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Add libraries to your favorites by tapping the heart icon on any library detail page.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.search),
            label: Text('Find Libraries'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xff1940CC),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _favoriteLibraries.length,
      itemBuilder: (context, index) {
        final library = _favoriteLibraries[index];
        return _buildLibraryCard(library);
      },
    );
  }

  Widget _buildLibraryCard(LibraryModel library) {
    // Get color based on library
    final Color libraryColor = _getColorForLibrary(library);

    // Build location string
    String location = '';
    if (library.address != null) {
      final address = library.address!;
      if (address['city'] != null) {
        location += address['city'].toString();
        if (address['state'] != null) {
          location += ', ' + address['state'].toString();
        }
      }
    } else if (library.location != null) {
      location = library.location!;
    } else {
      location = 'Location not specified';
    }

    return Dismissible(
      key: Key('favorite-${library.id}'),
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade900,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            title: Text('Remove from Favorites?'),
            content: Text('Are you sure you want to remove this library from your favorites?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Remove'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) => _removeFavorite(library.id!),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LibraryDetailScreen(
                library: library,
                isJoined: false, // This could be determined from another API call
              ),
            ),
          );
        },
        child: Container(
          margin: EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Library Image Section
              Stack(
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: library.libraryImageUrl != null
                        ? Image.network(
                      library.libraryImageUrl!,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 140,
                          color: libraryColor.withOpacity(0.2),
                          child: Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 40,
                              color: libraryColor.withOpacity(0.5),
                            ),
                          ),
                        );
                      },
                    )
                        : Container(
                      height: 140,
                      color: libraryColor.withOpacity(0.2),
                      child: Center(
                        child: Icon(
                          Icons.apartment,
                          size: 40,
                          color: libraryColor.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),

                  // Gradient overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Library name at bottom of image
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Text(
                      library.libraryName ?? 'Unnamed Library',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Rating badge
                  if (library.rating != null)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              library.rating!.toStringAsFixed(1),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Remove button
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.favorite,
                          color: Colors.red,
                          size: 20,
                        ),
                        constraints: BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () => _removeFavorite(library.id!),
                      ),
                    ),
                  ),
                ],
              ),

              // Library Info Section
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.grey,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            location,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 12),

                    // Tags/Facilities
                    if (library.utilities.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: library.utilities
                            .take(3)
                            .map((utility) => _buildUtilityChip(utility, libraryColor))
                            .toList(),
                      ),

                    // Show fee if available
                    SizedBox(height: 8),
                    if (library.lowFee != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: libraryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: libraryColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.currency_rupee,
                                  size: 14,
                                  color: libraryColor,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  "${library.lowFee}/mo",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: libraryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUtilityChip(String utility, Color color) {
    // Map of utility IDs to name/icon pairs
    final utilityData = {
      'wifi': {'name': 'WiFi', 'icon': Icons.wifi},
      'cctv': {'name': 'CCTV', 'icon': Icons.videocam},
      'water': {'name': 'RO Water', 'icon': Icons.water_drop},
      'ac': {'name': 'AC', 'icon': Icons.ac_unit},
      'printer': {'name': 'Printer', 'icon': Icons.print},
      'scanner': {'name': 'Scanner', 'icon': Icons.scanner},
      'locker': {'name': 'Lockers', 'icon': Icons.lock},
      'cafe': {'name': 'Cafeteria', 'icon': Icons.local_cafe},
      'parking': {'name': 'Parking', 'icon': Icons.local_parking},
      'charging': {'name': 'Charging', 'icon': Icons.power},
    };

    String name = 'Feature';
    IconData icon = Icons.star;

    if (utility.startsWith('custom_')) {
      name = utility.replaceAll('custom_', '').replaceAll('_', ' ');
    } else if (utilityData.containsKey(utility)) {
      name = utilityData[utility]!['name'] as String;
      icon = utilityData[utility]!['icon'] as IconData;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 4),
          Text(
            name,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForLibrary(LibraryModel library) {
    // Generate a consistent color based on library name or ID
    final seed = library.id?.hashCode ?? library.libraryName?.hashCode ?? 0;
    final colors = [
      Color(0xFF1E88E5), // Blue
      Color(0xFF43A047), // Green
      Color(0xFFE53935), // Red
      Color(0xFF8E24AA), // Purple
      Color(0xFFEF6C00), // Orange
      Color(0xFF00ACC1), // Cyan
    ];
    return colors[seed % colors.length];
  }
}