import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceInstancesModal extends StatelessWidget {
  final Map<String, dynamic> eventData;
  final String userId;

  const AttendanceInstancesModal({
    Key? key,
    required this.eventData,
    required this.userId,
  }) : super(key: key);

  String _formatDateTime(DateTime dateTime) {
    String day = dateTime.day.toString().padLeft(2, '0');
    String month = dateTime.month.toString().padLeft(2, '0');
    String year = dateTime.year.toString();
    String hour = dateTime.hour.toString().padLeft(2, '0');
    String minute = dateTime.minute.toString().padLeft(2, '0');
    
    return '$day/$month/$year at $hour:$minute';
  }

  String _getInstanceTitle(Map<String, dynamic> instanceData) {
    return instanceData['name'] ?? 'Instance';
  }

  String _getInstanceDateTime(Map<String, dynamic> instanceData) {
    if (instanceData.containsKey('startTime') && instanceData['startTime'] != null) {
      Timestamp timestamp = instanceData['startTime'] as Timestamp;
      DateTime dateTime = timestamp.toDate();
      return _formatDateTime(dateTime);
    }
    return '';
  }

  String _getAttendanceTime(Map<String, dynamic> attendanceData) {
    // Look for timeAttended field instead of timestamp
    if (attendanceData.containsKey('timeAttended') && attendanceData['timeAttended'] != null) {
      Timestamp timestamp = attendanceData['timeAttended'] as Timestamp;
      DateTime dateTime = timestamp.toDate();
      return 'Attended at ${_formatDateTime(dateTime)}';
    }
    return 'Attendance time not available';
  }

  bool _isUserPresent(Map<String, dynamic> instanceInfo) {
    // If attendanceData exists and has timeAttended, user is present
    Map<String, dynamic>? attendanceData = instanceInfo['attendanceData'];
    if (attendanceData != null && 
        attendanceData.containsKey('timeAttended') && 
        attendanceData['timeAttended'] != null) {
      return true;
    }
    return false; // If no attendance record exists, user is absent
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> event = eventData['eventData'];
    List<Map<String, dynamic>> attendedInstances = eventData['attendedInstances'];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event['name'] ?? 'Unknown Event',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.black54),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your attendance records',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.purple,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${attendedInstances.where((instance) => _isUserPresent(instance)).length} instances attended',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: attendedInstances.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      shrinkWrap: true,
                      itemCount: attendedInstances.length,
                      itemBuilder: (context, index) {
                        return _buildInstanceCard(attendedInstances[index]);
                      },
                    ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      backgroundColor: Colors.purple.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.w600,
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

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 60,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No instances found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No attendance records available for this event',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInstanceCard(Map<String, dynamic> instanceInfo) {
    Map<String, dynamic> instanceData = instanceInfo['instanceData'];
    Map<String, dynamic>? attendanceData = instanceInfo['attendanceData'];
    
    bool isPresent = _isUserPresent(instanceInfo);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPresent ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instance title and status
          Row(
            children: [
              Expanded(
                child: Text(
                  _getInstanceTitle(instanceData),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPresent 
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPresent ? Icons.check_circle : Icons.cancel,
                      size: 14,
                      color: isPresent ? Colors.green[600] : Colors.red[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPresent ? 'Present' : 'Absent',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isPresent ? Colors.green[600] : Colors.red[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Instance scheduled time
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 16,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 6),
              Text(
                'Scheduled: ${_getInstanceDateTime(instanceData)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),

          // Instance details
          if (instanceData.containsKey('location') && instanceData['location'].isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    instanceData['location'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Attendance information (only show if present)
          if (isPresent && attendanceData != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.green.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Attendance timestamp
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.green[600],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _getAttendanceTime(attendanceData),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Additional attendance info if available
                  if (attendanceData.containsKey('method')) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.how_to_reg,
                          size: 16,
                          color: Colors.green[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Method: ${attendanceData['method']}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Device info if available
                  if (attendanceData.containsKey('device')) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.phone_android,
                          size: 16,
                          color: Colors.green[600],
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Device: ${attendanceData['device']}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green[700],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

