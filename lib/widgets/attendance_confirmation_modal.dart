import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';

class AttendanceConfirmationModal extends StatefulWidget {
  final String eventId;
  final String eventName;
  final String instanceId;
  final String instanceName;
  final String locationId;
  final String locationName;
  final String status;
  final DateTime timeAttended;
  final double userLatitude;
  final double userLongitude;

  const AttendanceConfirmationModal({
    Key? key,
    required this.eventId,
    required this.eventName,
    required this.instanceId,
    required this.instanceName,
    required this.locationId,
    required this.locationName,
    required this.status,
    required this.timeAttended,
    required this.userLatitude,
    required this.userLongitude,
  }) : super(key: key);

  @override
  State<AttendanceConfirmationModal> createState() => _AttendanceConfirmationModalState();
}

class _AttendanceConfirmationModalState extends State<AttendanceConfirmationModal> {
  bool _isSubmitting = false;

  Future<void> _submitAttendance() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Fetch user information from local SQLite database
      final localUserData = await DatabaseService.getUserByUid(user.uid);
      if (localUserData == null) {
        throw Exception('User data not found in local database');
      }

      // Prepare attendance data with user information
      final attendanceData = {
        'userId': user.uid,
        'eventId': widget.eventId,
        'eventName': widget.eventName,
        'instanceId': widget.instanceId,
        'instanceName': widget.instanceName,
        'locationId': widget.locationId,
        'locationName': widget.locationName,
        'status': widget.status,
        'timeAttended': Timestamp.fromDate(widget.timeAttended),
        'userLocation': {
          'latitude': widget.userLatitude,
          'longitude': widget.userLongitude,
        },
        // User information from local database
        'userInfo': {
          'firstName': localUserData['firstName'] ?? '',
          'lastName': localUserData['lastName'] ?? '',
          'middleName': localUserData['middleName'] ?? '',
          'studentIdNumber': localUserData['studentIdNumber'] ?? '',
          'program': localUserData['program'] ?? '',
          'year': localUserData['year'] ?? '',
          'block': localUserData['block'] ?? '',
          'displayName': localUserData['displayName'] ?? '',
          'email': localUserData['email'] ?? '',
        },
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Store attendance in the instance's attendance subcollection
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('instances')
          .doc(widget.instanceId)
          .collection('attendance')
          .doc(user.uid) // Use user ID as document ID to prevent duplicates
          .set(attendanceData, SetOptions(merge: true));

      // Log successful submission with user info
      print('=== ATTENDANCE SUBMITTED SUCCESSFULLY ===');
      print('User ID: ${user.uid}');
      print('Student ID: ${localUserData['studentIdNumber']}');
      print('Name: ${localUserData['firstName']} ${localUserData['lastName']}');
      print('Program: ${localUserData['program']} - ${localUserData['year']} ${localUserData['block']}');
      print('Event ID: ${widget.eventId}');
      print('Instance ID: ${widget.instanceId}');
      print('Location ID: ${widget.locationId}');
      print('Status: ${widget.status}');
      print('Time: ${widget.timeAttended}');
      print('==========================================');

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance recorded: ${widget.status}'),
            backgroundColor: widget.status == 'Present' ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate back to dashboard using named route
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/dashboard',
          (route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      print('Error submitting attendance: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recording attendance: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _goBack() {
    if (!_isSubmitting && mounted) {
      Navigator.of(context).pop();
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    final month = months[dateTime.month - 1];
    final day = dateTime.day;
    final year = dateTime.year;
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    return '$month $day, $year at $displayHour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.status == 'Present' ? Colors.green : Colors.orange,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.status == 'Present' ? Icons.check_circle : Icons.warning,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Attendance Confirmation',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Activity / Event:', widget.eventName),
                  const SizedBox(height: 12),
                  _buildDetailRow('Attendance Instance:', widget.instanceName),
                  const SizedBox(height: 12),
                  _buildDetailRow('Location:', widget.locationName),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Status:',
                    widget.status,
                    valueColor: widget.status == 'Present' ? Colors.green : Colors.orange,
                    valueWeight: FontWeight.w600,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Time Attended:', _formatDateTime(widget.timeAttended)),
                  
                  const SizedBox(height: 20),
                  
                  // Status message
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.status == 'Present' 
                          ? Colors.green.shade50 
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.status == 'Present' 
                            ? Colors.green.shade300
                            : Colors.orange.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.status == 'Present' 
                              ? Icons.location_on 
                              : Icons.location_off,
                          color: widget.status == 'Present' 
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.status == 'Present'
                                ? 'You are currently within the event location.'
                                : 'You are currently outside the event location.',
                            style: TextStyle(
                              fontSize: 14,
                              color: widget.status == 'Present' 
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : _goBack,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: _isSubmitting ? Colors.grey : Colors.grey.shade600,
                        ),
                      ),
                      child: Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 16,
                          color: _isSubmitting ? Colors.grey : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitAttendance,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.status == 'Present' 
                            ? Colors.green 
                            : Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        disabledBackgroundColor: Colors.grey,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Confirm',
                              style: TextStyle(fontSize: 16),
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

  Widget _buildDetailRow(
    String label, 
    String value, {
    Color? valueColor,
    FontWeight? valueWeight,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: valueWeight ?? FontWeight.normal,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}