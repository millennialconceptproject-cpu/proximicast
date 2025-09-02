import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../map_attendance_screen.dart';


class LocationSelectionModal extends StatefulWidget {
  final String eventId;
  final String instanceId;
  final String instanceName;
  final Map<String, dynamic> eventDetails;

  const LocationSelectionModal({
    Key? key,
    required this.eventId,
    required this.instanceId,
    required this.instanceName,
    required this.eventDetails,
  }) : super(key: key);

  @override
  State<LocationSelectionModal> createState() => _LocationSelectionModalState();
}

class _LocationSelectionModalState extends State<LocationSelectionModal> {
  List<Map<String, dynamic>> locations = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    try {
      // Get event data from Firestore to get locationIds
      final eventData = await DatabaseService.getEventFromFirestore(widget.eventId);
      final locationIds = List<String>.from(eventData['locationIds'] ?? []);
      
      // Get location details for each locationId from Firestore
      List<Map<String, dynamic>> locationsList = [];
      for (String locationId in locationIds) {
        try {
          final locationData = await DatabaseService.getLocationFromFirestore(locationId);
          if (locationData.isNotEmpty) {
            locationsList.add({
              ...locationData,
              'eligibility': _determineLocationEligibility(),
            });
          }
        } catch (e) {
          print('Error loading location $locationId: $e');
        }
      }

      if (mounted) {
        setState(() {
          locations = locationsList;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading locations: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String _determineLocationEligibility() {
    // Since we can only reach this modal if the instance is active or late,
    // all locations are eligible for attendance
    final now = DateTime.now();
    final eventEndTime = DateTime.parse(widget.eventDetails['endDate']);
    
    if (now.isAfter(eventEndTime)) {
      return 'Event has ended';
    }
    
    return 'Available for attendance';
  }

  String _formatLocationAddress(Map<String, dynamic> location) {
    final street = location['street'] ?? '';
    final barangay = location['barangay'] ?? '';
    final city = location['city'] ?? '';
    final province = location['province'] ?? '';
    
    List<String> addressParts = [];
    if (street.isNotEmpty) addressParts.add(street);
    if (barangay.isNotEmpty) addressParts.add(barangay);
    if (city.isNotEmpty) addressParts.add(city);
    if (province.isNotEmpty) addressParts.add(province);
    
    return addressParts.join(', ');
  }

  void _onLocationTap(Map<String, dynamic> location) async {
    // Log the location selection
    _logLocationSelection(location);
    
    try {
      // Navigate to map attendance screen
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MapAttendanceScreen(
            eventId: widget.eventId,
            instanceId: widget.instanceId,
            instanceName: widget.instanceName,
            eventDetails: widget.eventDetails,
            selectedLocation: location,
          ),
        ),
      );
    } catch (e) {
      print('Error navigating to map screen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening map: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _logLocationSelection(Map<String, dynamic> location) {
    // Log the location selection to console
    print('=== LOCATION SELECTED ===');
    print('Event ID: ${widget.eventId}');
    print('Event Name: ${widget.eventDetails['eventName']}');
    print('Instance ID: ${widget.instanceId}');
    print('Instance Name: ${widget.instanceName}');
    print('Location ID: ${location['id']}');
    print('Location Name: ${location['locationName']}');
    print('Location Address: ${_formatLocationAddress(location)}');
    print('========================');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.purple,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Location',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.instanceName,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : locations.isEmpty
                      ? const Center(
                          child: Text(
                            'No locations available',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: locations.length,
                          itemBuilder: (context, index) {
                            final location = locations[index];
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GestureDetector(
                                onTap: () => _onLocationTap(location),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.green,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              location['locationName'] ?? 'Unknown Location',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Address: ${_formatLocationAddress(location)}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade700,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              location['eligibility'] ?? '',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.green.shade700,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.location_on,
                                        color: Colors.purple,
                                        size: 24,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}