import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'location_selection_modal.dart';

class InstanceSelectionModal extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> eventDetails;

  const InstanceSelectionModal({
    Key? key,
    required this.eventId,
    required this.eventDetails,
  }) : super(key: key);

  @override
  State<InstanceSelectionModal> createState() => _InstanceSelectionModalState();
}

class _InstanceSelectionModalState extends State<InstanceSelectionModal> {
  List<Map<String, dynamic>> instances = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInstances();
  }

  Future<void> _loadInstances() async {
    try {
      final instancesData = await DatabaseService.getEventInstances(widget.eventId);
      
      // Sort instances by startTime to determine order
      instancesData.sort((a, b) {
        final aTime = (a['startTime'] as Timestamp).toDate();
        final bTime = (b['startTime'] as Timestamp).toDate();
        return aTime.compareTo(bTime);
      });

      List<Map<String, dynamic>> processedInstances = [];
      for (var instance in instancesData) {
        // First check if user has already attended this instance
        final hasAttended = await _checkUserAttendanceForInstance(instance['id']);
        
        if (hasAttended) {
          // If user has attended, mark as completed
          processedInstances.add({
            ...instance,
            'status': 'completed',
            'eligibility': 'Already attended',
            'hasAttended': true,
          });
        } else {
          // If not attended, determine normal status
          final status = await _determineInstanceStatus(instance, instancesData);
          processedInstances.add({
            ...instance,
            'status': status,
            'eligibility': _determineEligibility(instance, status),
            'hasAttended': false,
          });
        }
      }

      setState(() {
        instances = processedInstances;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading instances: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<bool> _checkUserAttendanceForInstance(String instanceId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      print('=== CHECKING ATTENDANCE FOR INSTANCE ===');
      print('Event ID: ${widget.eventId}');
      print('Instance ID: $instanceId');
      print('User ID: ${user.uid}');

      // Check if user has attendance record for this specific instance
      final attendanceDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('instances')
          .doc(instanceId)
          .collection('attendance')
          .doc(user.uid)
          .get();

      print('Has attendance record: ${attendanceDoc.exists}');
      if (attendanceDoc.exists) {
        print('Attendance data: ${attendanceDoc.data()}');
      }
      print('========================================');

      return attendanceDoc.exists;
    } catch (e) {
      print('Error checking user attendance for instance: $e');
      return false;
    }
  }

  Future<String> _determineInstanceStatus(Map<String, dynamic> instance, List<Map<String, dynamic>> allInstances) async {
    final now = DateTime.now();
    final startTime = (instance['startTime'] as Timestamp).toDate();
    final endTime = (instance['endTime'] as Timestamp).toDate();
    final eventEndTime = DateTime.parse(widget.eventDetails['endDate']);

    // Check if event has already ended
    if (now.isAfter(eventEndTime)) {
      return 'inactive';
    }

    // Check if startTime hasn't started yet
    if (now.isBefore(startTime)) {
      return 'inactive';
    }

    // Check tied instance logic (AM, PM, Evening Time In/Out)
    final instanceName = instance['name'].toString().toLowerCase();
    if (instanceName.contains('time out')) {
      // This is a time out instance, check if corresponding time in was attended
      String correspondingTimeIn = instanceName.replaceAll('time out', 'time in');
      bool timeInAttended = await _checkIfInstanceAttended(correspondingTimeIn, allInstances);
      
      if (!timeInAttended) {
        return 'inactive'; // Cannot attend time out without time in
      }
    }

    // Find the next instance
    final currentIndex = allInstances.indexWhere((inst) => inst['id'] == instance['id']);
    if (currentIndex < allInstances.length - 1) {
      final nextInstance = allInstances[currentIndex + 1];
      final nextStartTime = (nextInstance['startTime'] as Timestamp).toDate();
      
      // Check if next instance has already started
      if (now.isAfter(nextStartTime)) {
        return 'inactive';
      }
    }

    // Check if currently within the time window
    if (now.isAfter(startTime) && now.isBefore(endTime)) {
      return 'active';
    }

    // Check if it's past endTime but before next instance (late attendance)
    if (now.isAfter(endTime)) {
      if (currentIndex < allInstances.length - 1) {
        final nextInstance = allInstances[currentIndex + 1];
        final nextStartTime = (nextInstance['startTime'] as Timestamp).toDate();
        if (now.isBefore(nextStartTime)) {
          return 'late';
        }
      } else {
        // Last instance, allow late attendance until event ends
        return 'late';
      }
    }

    return 'inactive';
  }

  // Check if a user has already attended a specific instance by name
  Future<bool> _checkIfInstanceAttended(String instanceName, List<Map<String, dynamic>> allInstances) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Find the instance by name
      final targetInstance = allInstances.firstWhere(
        (inst) => inst['name'].toString().toLowerCase() == instanceName,
        orElse: () => <String, dynamic>{},
      );

      if (targetInstance.isEmpty) return false;

      // Check if user has attendance record for this instance using the new structure
      final attendanceDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('instances')
          .doc(targetInstance['id'])
          .collection('attendance')
          .doc(user.uid)
          .get();

      return attendanceDoc.exists;
    } catch (e) {
      print('Error checking instance attendance: $e');
      return false;
    }
  }

  String _determineEligibility(Map<String, dynamic> instance, String status) {
    final startTime = (instance['startTime'] as Timestamp).toDate();
    final endTime = (instance['endTime'] as Timestamp).toDate();
    
    final startTimeFormatted = _formatTime(startTime);
    final endTimeFormatted = _formatTime(endTime);
    
    switch (status) {
      case 'active':
        return 'Active until $endTimeFormatted';
      case 'late':
        return 'Late attendance allowed';
      case 'inactive':
      default:
        if (DateTime.now().isBefore(startTime)) {
          return 'Available from $startTimeFormatted';
        } else {
          final instanceName = instance['name'].toString().toLowerCase();
          if (instanceName.contains('time out') && !instanceName.contains('time in')) {
            return 'Requires corresponding Time In';
          }
          return 'No longer available';
        }
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }

  bool _canProceedToLocation(String status) {
    return (status == 'active' || status == 'late') && status != 'completed';
  }

  void _onInstanceTap(Map<String, dynamic> instance) {
    if (_canProceedToLocation(instance['status'])) {
      Navigator.of(context).pop(); // Close current modal
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return LocationSelectionModal(
            eventId: widget.eventId,
            instanceId: instance['id'],
            instanceName: instance['name'],
            eventDetails: widget.eventDetails,
          );
        },
      );
    }
  }

  Color _getContainerColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green.shade50;
      case 'late':
        return Colors.orange.shade50;
      case 'completed':
        return Colors.blue.shade50;
      case 'inactive':
      default:
        return Colors.grey.shade100;
    }
  }

  Color _getBorderColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'late':
        return Colors.orange;
      case 'completed':
        return Colors.blue;
      case 'inactive':
      default:
        return Colors.grey.shade300;
    }
  }

  Color _getTextColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green.shade700;
      case 'late':
        return Colors.orange.shade700;
      case 'completed':
        return Colors.blue.shade700;
      case 'inactive':
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'active':
        return Icons.play_circle_outline;
      case 'late':
        return Icons.schedule;
      case 'completed':
        return Icons.check_circle;
      case 'inactive':
      default:
        return Icons.lock_outline;
    }
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
                          'Select Attendance Instance',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.eventDetails['eventName'] ?? 'Event',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
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
                  : instances.isEmpty
                      ? const Center(
                          child: Text(
                            'No attendance instances available',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: instances.length,
                          itemBuilder: (context, index) {
                            final instance = instances[index];
                            final canProceed = _canProceedToLocation(instance['status']);
                            final status = instance['status'];
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GestureDetector(
                                onTap: () => _onInstanceTap(instance),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: _getContainerColor(status),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _getBorderColor(status),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Status icon
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: _getBorderColor(status).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          _getStatusIcon(status),
                                          color: _getBorderColor(status),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      
                                      // Instance details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              instance['name'] ?? 'Unknown Instance',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: canProceed ? Colors.black87 : Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              instance['eligibility'] ?? '',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: _getTextColor(status),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Action arrow or lock
                                      Icon(
                                        canProceed ? Icons.arrow_forward_ios : Icons.block,
                                        color: canProceed ? Colors.purple : Colors.grey,
                                        size: 20,
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