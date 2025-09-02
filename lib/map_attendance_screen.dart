import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import for GeoPoint
import '../services/database_service.dart';
import '../services/geofencing_service.dart';
import 'widgets/attendance_confirmation_modal.dart';
import 'dart:async';

class MapAttendanceScreen extends StatefulWidget {
  final String eventId;
  final String instanceId;
  final String instanceName;
  final Map<String, dynamic> eventDetails;
  final Map<String, dynamic> selectedLocation;

  const MapAttendanceScreen({
    Key? key,
    required this.eventId,
    required this.instanceId,
    required this.instanceName,
    required this.eventDetails,
    required this.selectedLocation,
  }) : super(key: key);

  @override
  State<MapAttendanceScreen> createState() => _MapAttendanceScreenState();
}

class _MapAttendanceScreenState extends State<MapAttendanceScreen> {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  List<LatLng> _locationBoundary = [];
  bool _isLoading = true;
  bool _hasLocationPermission = false;
  bool _isMapReady = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    try {
      // Check and request permissions
      final permissionGranted = await _checkLocationPermission();
      if (!permissionGranted) {
        return;
      }

      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Location services are disabled. Please enable location services.';
          _isLoading = false;
        });
        _showLocationServicesDialog();
        return;
      }

      // Load location boundary coordinates
      await _loadLocationBoundary();

      // Get current position and start tracking
      await _getCurrentLocation();
      _startLocationTracking();

    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing location: $e';
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      _showPermissionDeniedDialog();
      return false;
    }

    if (permission == LocationPermission.denied) {
      _showPermissionDeniedDialog();
      return false;
    }

    setState(() {
      _hasLocationPermission = true;
    });
    return true;
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'Location permission is required for attendance tracking. Please grant location permission to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _checkLocationPermission();
              },
              child: const Text('Retry'),
            ),
          ],
        );
      },
    );
  }

  void _showLocationServicesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Services Disabled'),
          content: const Text(
            'Location services are required for attendance tracking. Please enable location services in your device settings.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _initializeLocation();
              },
              child: const Text('Retry'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadLocationBoundary() async {
    try {
      // Get full location details from Firestore to access coordinates
      final locationData = await DatabaseService.getLocationFromFirestore(
        widget.selectedLocation['id']
      );

      print('=== LOCATION DATA DEBUG ===');
      print('Location ID: ${widget.selectedLocation['id']}');
      print('Raw location data: $locationData');
      print('Coordinates field: ${locationData['coordinates']}');
      print('Coordinates type: ${locationData['coordinates'].runtimeType}');
      print('========================');

      final coordinates = locationData['coordinates'] as List<dynamic>;
      
      List<LatLng> boundary = [];
      
      print('=== COORDINATE PARSING DEBUG ===');
      print('Number of coordinates to parse: ${coordinates.length}');
      
      for (int i = 0; i < coordinates.length; i++) {
        var coord = coordinates[i];
        print('Coordinate [$i]: $coord (Type: ${coord.runtimeType})');
        
        // Handle GeoPoint objects from Firestore
        if (coord is GeoPoint) {
          final lat = coord.latitude;
          final lng = coord.longitude;
          boundary.add(LatLng(lat, lng));
          print('  ✅ GeoPoint parsed successfully: Lat $lat, Lng $lng');
        }
        // Handle string coordinates (backup for different formats)
        else if (coord is String) {
          // Try multiple regex patterns to handle different formats
          RegExpMatch? latLngMatch;
          
          // Pattern 1: [9.9139° N, 123.922409° E]
          latLngMatch = RegExp(r'\[([0-9.]+)° N, ([0-9.]+)° E\]').firstMatch(coord);
          
          // Pattern 2: [9.9139°N, 123.922409°E] (no spaces)
          if (latLngMatch == null) {
            latLngMatch = RegExp(r'\[([0-9.]+)°N, ([0-9.]+)°E\]').firstMatch(coord);
          }
          
          // Pattern 3: 9.9139° N, 123.922409° E (no brackets)
          if (latLngMatch == null) {
            latLngMatch = RegExp(r'([0-9.]+)° N, ([0-9.]+)° E').firstMatch(coord);
          }
          
          // Pattern 4: Simple comma-separated lat,lng
          if (latLngMatch == null) {
            latLngMatch = RegExp(r'([0-9.]+),\s*([0-9.]+)').firstMatch(coord);
          }
          
          if (latLngMatch != null) {
            final lat = double.parse(latLngMatch.group(1)!);
            final lng = double.parse(latLngMatch.group(2)!);
            boundary.add(LatLng(lat, lng));
            print('  ✅ String parsed successfully: Lat $lat, Lng $lng');
          } else {
            print('  ❌ Failed to parse string coordinate: $coord');
          }
        }
        // Handle Map objects (in case coordinates are stored as objects)
        else if (coord is Map<String, dynamic>) {
          if (coord.containsKey('latitude') && coord.containsKey('longitude')) {
            final lat = coord['latitude'] as double;
            final lng = coord['longitude'] as double;
            boundary.add(LatLng(lat, lng));
            print('  ✅ Map object parsed successfully: Lat $lat, Lng $lng');
          } else {
            print('  ❌ Map object missing lat/lng keys: $coord');
          }
        }
        else {
          print('  ❌ Unknown coordinate type: ${coord.runtimeType}');
        }
      }
      
      print('Total parsed coordinates: ${boundary.length}');
      print('Final boundary points:');
      for (int i = 0; i < boundary.length; i++) {
        print('  Boundary [$i]: Lat ${boundary[i].latitude}, Lng ${boundary[i].longitude}');
      }
      print('==============================');

      setState(() {
        _locationBoundary = boundary;
      });
      
      // If we have coordinates and map is ready, center the view
      if (boundary.isNotEmpty && _isMapReady && _currentPosition != null) {
        _centerMapOnLocation();
      }
    } catch (e) {
      print('Error loading location boundary: $e');
      setState(() {
        _errorMessage = 'Error loading location boundary: $e';
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      // Center map on current location after a small delay to ensure map is ready
      _centerMapOnLocation();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error getting current location: $e';
        _isLoading = false;
      });
    }
  }

  void _centerMapOnLocation() {
    if (_currentPosition == null) return;
    
    // Use a post-frame callback to ensure the map is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (_locationBoundary.isNotEmpty) {
          // Calculate bounds to show both user location and venue boundary
          final bounds = LatLngBounds.fromPoints([
            ..._locationBoundary,
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          ]);
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: bounds, 
              padding: const EdgeInsets.all(50),
            ),
          );
        } else {
          _mapController.move(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 
            16.0,
          );
        }
      } catch (e) {
        print('Error centering map: $e');
        // If centering fails, just continue - the map will show default location
      }
    });
  }

  void _startLocationTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        setState(() {
          _currentPosition = position;
        });
      },
      onError: (e) {
        print('Location tracking error: $e');
      },
    );
  }

  void _onAttendButtonPressed() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Getting your location, please wait...')),
      );
      return;
    }

    try {
      // Log detailed coordinate information
      print('=== ATTENDANCE ATTEMPT ===');
      print('Event ID: ${widget.eventId}');
      print('Instance ID: ${widget.instanceId}');
      print('Location ID: ${widget.selectedLocation['id']}');
      print('Location Name: ${widget.selectedLocation['locationName']}');
      print('');
      
      // Log user's current coordinates
      print('USER LOCATION:');
      print('Latitude: ${_currentPosition!.latitude}');
      print('Longitude: ${_currentPosition!.longitude}');
      print('');
      
      // Log venue boundary vertices
      print('VENUE BOUNDARY VERTICES (${_locationBoundary.length} points):');
      for (int i = 0; i < _locationBoundary.length; i++) {
        final vertex = _locationBoundary[i];
        print('Vertex [$i]: Lat ${vertex.latitude}, Lng ${vertex.longitude}');
      }
      print('');

      // Use geofencing service to check if user is inside the boundary
      final isInside = GeofencingService.isPointInPolygon(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        _locationBoundary,
      );

      final status = isInside ? 'Present' : 'Absent';
      final timeAttended = DateTime.now();

      // Log the result
      print('GEOFENCING RESULT:');
      print('Is user inside boundary: $isInside');
      print('Attendance Status: $status');
      print('Time: $timeAttended');
      print('=========================');

      // Show confirmation modal
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AttendanceConfirmationModal(
            eventId: widget.eventId,
            eventName: widget.eventDetails['eventName'],
            instanceId: widget.instanceId,
            instanceName: widget.instanceName,
            locationId: widget.selectedLocation['id'],
            locationName: widget.selectedLocation['locationName'],
            status: status,
            timeAttended: timeAttended,
            userLatitude: _currentPosition!.latitude,
            userLongitude: _currentPosition!.longitude,
          ),
        );
      }
    } catch (e) {
      print('Error processing attendance: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing attendance: $e')),
      );
    }
  }

  void _onCancelButtonPressed() {
    Navigator.of(context).pop(); // Go back to location selection
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Location'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _onCancelButtonPressed,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                            _isLoading = true;
                          });
                          _initializeLocation();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Event info header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        border: Border(
                          bottom: BorderSide(color: Colors.purple.shade200),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.eventDetails['eventName'] ?? 'Unknown Event',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.purple,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Instance: ${widget.instanceName}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.purple.shade700,
                            ),
                          ),
                          Text(
                            'Location: ${widget.selectedLocation['locationName']}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Map
                    Expanded(
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          onMapReady: () {
                            setState(() {
                              _isMapReady = true;
                            });
                            _centerMapOnLocation();
                          },
                          initialCenter: _currentPosition != null
                              ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                              : const LatLng(9.9139, 123.922409), // Default to first coordinate
                          initialZoom: 16.0,
                        ),
                        children: [
                          // OpenStreetMap tiles
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.proximicast',
                          ),
                          
                          // Location boundary polygon
                          if (_locationBoundary.isNotEmpty)
                            PolygonLayer(
                              polygons: [
                                Polygon(
                                  points: _locationBoundary,
                                  color: Colors.purple.withOpacity(0.3),
                                  borderColor: Colors.purple,
                                  borderStrokeWidth: 2,
                                ),
                              ],
                            ),
                          
                          // Current location marker
                          if (_currentPosition != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                                  width: 40,
                                  height: 40,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.my_location,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    
                    // Bottom buttons
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _onCancelButtonPressed,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: const BorderSide(color: Colors.grey),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _onAttendButtonPressed,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text(
                                'Attend',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}