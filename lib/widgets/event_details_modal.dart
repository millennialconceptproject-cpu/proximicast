import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:proximicast/services/event_service.dart';
import 'instance_selection_modal.dart';

class EventDetailsModal extends StatelessWidget {
  final Map<String, dynamic> eventDetails;

  const EventDetailsModal({
    Key? key,
    required this.eventDetails,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.purple.shade200,
                    Colors.purple.shade400,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Upcoming Activity',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    eventDetails['eventName'] ?? 'No upcoming activities yet',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eventDetails['eventName'] != 'No upcoming activities yet') ...[
                      // Description
                      _buildInfoSection(
                        'Description:',
                        eventDetails['description'] ?? 'No description available',
                      ),
                      const SizedBox(height: 20),
                      
                      // Location - Use EventService method for location names only
                      FutureBuilder<String>(
                        future: EventService.getLocationNames(eventDetails['eventId'] ?? ''),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return _buildInfoSection(
                              'Location:',
                              'Loading location...',
                            );
                          }
                          return _buildInfoSection(
                            'Location:',
                            snapshot.data ?? eventDetails['locationText'] ?? 'Location not available',
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      
                      // Date
                      _buildInfoSection(
                        'Date:',
                        _getDateOnly(eventDetails['dateTimeText'] ?? ''),
                      ),
                      const SizedBox(height: 20),
                      
                      // Timeframe
                      _buildInfoSection(
                        'Timeframe:',
                        _getTimeframe(),
                      ),
                      const SizedBox(height: 30),
                    ] else ...[
                      // No events message
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No upcoming activities scheduled',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Check back later for new events and activities.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ],
                ),
              ),
            ),
            
            // Bottom section with Cast button
            if (eventDetails['eventName'] != 'No upcoming activities yet')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            eventDetails['statusMessage'] ?? '',
                            style: TextStyle(
                              fontSize: 16,
                              color: eventDetails['canCast'] == true 
                                  ? Colors.purple 
                                  : Colors.grey[600],
                              fontWeight: eventDetails['canCast'] == true 
                                  ? FontWeight.w600 
                                  : FontWeight.w500,
                            ),
                          ),
                          if (eventDetails['canCast'] != true)
                            Text(
                              'Button will be enabled on the event day',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: eventDetails['canCast'] == true 
                          ? () {
                              Navigator.of(context).pop(); // Close current modal
                              // Show instance selection modal
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return InstanceSelectionModal(
                                    eventId: eventDetails['eventId'],
                                    eventDetails: eventDetails,
                                  );
                                },
                              );
                            }
                          : null,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: eventDetails['canCast'] == true
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.purple.shade200,
                                    Colors.purple.shade400,
                                  ],
                                )
                              : LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.grey.shade300,
                                    Colors.grey.shade400,
                                  ],
                                ),
                          shape: BoxShape.circle,
                          boxShadow: eventDetails['canCast'] == true
                              ? [
                                  BoxShadow(
                                    color: Colors.purple.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String label, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.black54,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  String _getDateOnly(String dateTimeText) {
    if (dateTimeText.isEmpty) return 'Date not available';
    
    // Extract date part from the formatted string
    if (dateTimeText.contains(',')) {
      // Format: "Aug. 31, 2025, 8:00 AM - 5:00 PM"
      List<String> parts = dateTimeText.split(',');
      if (parts.length >= 2) {
        return '${parts[0]}, ${parts[1]}';
      }
    }
    
    // Format: "Aug. 31 - Sep. 1, 2025"
    return dateTimeText;
  }

  String _getTimeframe() {
    // Use EventService method if we have the required data
    if (eventDetails['startDate'] != null && eventDetails['endDate'] != null) {
      try {
        DateTime startDate = DateTime.parse(eventDetails['startDate']);
        DateTime endDate = DateTime.parse(eventDetails['endDate']);
        return EventService.getTimeframe(startDate, endDate);
      } catch (e) {
        print('Error parsing dates for timeframe: $e');
      }
    }
    
    // Fallback: extract from dateTimeText
    String dateTimeText = eventDetails['dateTimeText'] ?? '';
    
    if (dateTimeText.contains('AM') || dateTimeText.contains('PM')) {
      // Extract time part
      List<String> parts = dateTimeText.split(',');
      if (parts.length >= 3) {
        return parts[2].trim(); // "8:00 AM - 5:00 PM"
      }
    }
    
    return 'All day event';
  }
}