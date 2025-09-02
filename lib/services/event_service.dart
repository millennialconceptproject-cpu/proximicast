import 'package:intl/intl.dart';
import 'database_service.dart';

class EventService {
  
  static Future<Map<String, dynamic>?> getUpcomingEventDetails() async {
    try {
      // Get the upcoming event from local database
      Map<String, dynamic>? eventData = await DatabaseService.getUpcomingEvent();
      
      if (eventData == null) {
        return null;
      }

      // Parse the event data with null safety
      DateTime startDate = DateTime.parse(eventData['startDate']);
      DateTime endDate = DateTime.parse(eventData['endDate']);
      DateTime now = DateTime.now();
      int notifyDaysBefore = eventData['notifyDaysBefore'] ?? 0;

      // Check if the event should be shown based on notifyDaysBefore
      DateTime notificationDate = startDate.subtract(Duration(days: notifyDaysBefore));
      
      if (now.isBefore(notificationDate)) {
        return null; // Event is too far in the future
      }

      // Get location names with proper null handling
      String locationText = '';
      String? locationIdsString = eventData['locationIds']?.toString();
      
      if (locationIdsString != null && locationIdsString.isNotEmpty) {
        List<String> locationIds = locationIdsString
            .split(',')
            .where((id) => id.trim().isNotEmpty)
            .map((id) => id.trim())
            .toList();
        
        if (locationIds.isNotEmpty) {
          List<Map<String, dynamic>> locations = await DatabaseService.getLocationsByIds(locationIds);
          
          if (locations.isNotEmpty) {
            List<String> locationNames = locations
                .map((loc) => (loc['locationName'] ?? 'Unknown Location').toString())
                .toList();
            locationText = locationNames.join(', ');
            
            // Truncate if too long
            if (locationText.length > 30) {
              locationText = '${locationText.substring(0, 27)}...';
            }
          }
        }
      }

      // Format date and time
      String dateTimeText = _formatDateTime(startDate, endDate);

      // Determine event status
      bool isEventDay = _isSameDay(now, startDate) || (now.isAfter(startDate) && now.isBefore(endDate));
      bool canCast = isEventDay;
      
      String statusMessage;
      if (isEventDay) {
        statusMessage = 'Cast Now';
      } else {
        int daysUntilEvent = startDate.difference(now).inDays;
        if (daysUntilEvent < 0) {
          statusMessage = 'Event has ended';
        } else {
          statusMessage = 'Attendance is in ${daysUntilEvent} day${daysUntilEvent == 1 ? '' : 's'}';
        }
      }

      return {
        'eventName': eventData['name'] ?? 'Unnamed Event',
        'description': eventData['description'] ?? 'No description available',
        'locationText': locationText,
        'dateTimeText': dateTimeText,
        'statusMessage': statusMessage,
        'canCast': canCast,
        'eventId': eventData['id'],
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      };

    } catch (e) {
      print('Error getting upcoming event details: $e');
      print('Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  static String _formatDateTime(DateTime startDate, DateTime endDate) {
    if (_isSameDay(startDate, endDate)) {
      // Same day, show date with time range
      String dateStr = DateFormat('MMM. d, yyyy').format(startDate);
      String startTime = DateFormat('h:mm a').format(startDate);
      String endTime = DateFormat('h:mm a').format(endDate);
      return '$dateStr, $startTime - $endTime';
    } else {
      // Different days, show date range only
      String startDateStr = DateFormat('MMM. d').format(startDate);
      String endDateStr = DateFormat('MMM. d, yyyy').format(endDate);
      return '$startDateStr - $endDateStr';
    }
  }

  static bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }

  static Future<void> syncEventData() async {
    try {
      await DatabaseService.fetchAndStoreEventsFromFirestore();
      await DatabaseService.fetchAndStoreLocationsFromFirestore();
      print('Event data synced successfully');
    } catch (e) {
      print('Error syncing event data: $e');
      // Don't throw here, as we want the app to work with local data if sync fails
    }
  }

  // Helper method to get location names only
  static Future<String> getLocationNames(String eventId) async {
    try {
      // Get event data from local database
      final events = await DatabaseService.getAllEvents();
      final event = events.firstWhere(
        (e) => e['id'] == eventId,
        orElse: () => <String, dynamic>{},
      );
      
      if (event.isEmpty) return 'Location not available';
      
      // Get location IDs with proper null handling
      String? locationIdsString = event['locationIds']?.toString();
      if (locationIdsString == null || locationIdsString.isEmpty) {
        return 'Location not specified';
      }
      
      List<String> locationIds = locationIdsString
          .split(',')
          .where((id) => id.trim().isNotEmpty)
          .map((id) => id.trim())
          .toList();
      
      if (locationIds.isEmpty) return 'Location not specified';
      
      // Get location details
      List<Map<String, dynamic>> locations = await DatabaseService.getLocationsByIds(locationIds);
      
      if (locations.isEmpty) return 'Location details not available';
      
      // Return only location names
      List<String> locationNames = locations
          .map((loc) => (loc['locationName'] ?? 'Unknown Location').toString())
          .toList();
      
      return locationNames.join(', ');
    } catch (e) {
      print('Error getting location names: $e');
      return 'Error loading location names';
    }
  }

  // Helper method to format time range for modal
  static String getTimeframe(DateTime startDate, DateTime endDate) {
    if (_isSameDay(startDate, endDate)) {
      String startTime = DateFormat('h:mm a').format(startDate);
      String endTime = DateFormat('h:mm a').format(endDate);
      return '$startTime - $endTime';
    } else {
      // Multi-day event
      String startTime = DateFormat('h:mm a').format(startDate);
      String endTime = DateFormat('h:mm a').format(endDate);
      String startDateStr = DateFormat('MMM. d').format(startDate);
      String endDateStr = DateFormat('MMM. d').format(endDate);
      return '$startDateStr at $startTime - $endDateStr at $endTime';
    }
  }
}