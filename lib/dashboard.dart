import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/database_service.dart';
import 'services/event_service.dart';
import 'widgets/event_details_modal.dart';
import 'widgets/instance_selection_modal.dart';
import 'widgets/user_account_popup.dart';
import 'widgets/attendance_instances_modal.dart';

void main() {
  runApp(const DashboardApp());
}

class DashboardApp extends StatelessWidget {
  const DashboardApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const Dashboard(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({Key? key}) : super(key: key);

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  Map<String, dynamic>? upcomingEventDetails;
  bool isLoading = true;
  bool isShowingUserPopup = false;
  OverlayEntry? _overlayEntry;
  
  // Tab management
  int _currentTabIndex = 0;
  List<Map<String, dynamic>> attendedEvents = [];
  bool isLoadingAttendance = false;
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadEventData();
  }

  Future<void> _loadEventData() async {
    try {
      // First, try to sync data from Firestore
      await EventService.syncEventData();
      
      // Then get the upcoming event details
      Map<String, dynamic>? eventDetails = await EventService.getUpcomingEventDetails();
      
      setState(() {
        upcomingEventDetails = eventDetails;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading event data: $e');
      // Still try to get local data if sync fails
      try {
        Map<String, dynamic>? eventDetails = await EventService.getUpcomingEventDetails();
        setState(() {
          upcomingEventDetails = eventDetails;
          isLoading = false;
        });
      } catch (e) {
        print('Error getting local event data: $e');
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAttendanceHistory() async {
    if (currentUserId == null) {
      setState(() {
        isLoadingAttendance = false;
      });
      return;
    }

    try {
      setState(() {
        isLoadingAttendance = true;
      });

      List<Map<String, dynamic>> eventsWithAttendance = [];
      
      // Get all events
      QuerySnapshot eventsSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .get();

      for (QueryDocumentSnapshot eventDoc in eventsSnapshot.docs) {
        String eventId = eventDoc.id;
        Map<String, dynamic> eventData = eventDoc.data() as Map<String, dynamic>;
        
        // Get location names for this event
        String locationText = '';
        if (eventData.containsKey('locationIds') && eventData['locationIds'] is List) {
          List<String> locationIds = List<String>.from(eventData['locationIds']);
          List<String> locationNames = [];
          
          for (String locationId in locationIds) {
            try {
              DocumentSnapshot locationDoc = await FirebaseFirestore.instance
                  .collection('locations')
                  .doc(locationId)
                  .get();
              
              if (locationDoc.exists) {
                Map<String, dynamic> locationData = locationDoc.data() as Map<String, dynamic>;
                String locationName = locationData['name'] ?? locationData['locationName'] ?? 'Unknown Location';
                locationNames.add(locationName);
              }
            } catch (e) {
              print('Error fetching location $locationId: $e');
            }
          }
          
          locationText = locationNames.isEmpty ? 'No location specified' : locationNames.join(', ');
        } else {
          locationText = 'No location specified';
        }
        
        // Add location text to event data
        eventData['locationText'] = locationText;
        
        // Get instances for this event
        QuerySnapshot instancesSnapshot = await FirebaseFirestore.instance
            .collection('events')
            .doc(eventId)
            .collection('instances')
            .get();

        List<Map<String, dynamic>> attendedInstances = [];
        
        for (QueryDocumentSnapshot instanceDoc in instancesSnapshot.docs) {
          String instanceId = instanceDoc.id;
          
          // Check if user attended this instance
          DocumentSnapshot attendanceDoc = await FirebaseFirestore.instance
              .collection('events')
              .doc(eventId)
              .collection('instances')
              .doc(instanceId)
              .collection('attendance')
              .doc(currentUserId)
              .get();

          if (attendanceDoc.exists) {
            Map<String, dynamic> instanceData = instanceDoc.data() as Map<String, dynamic>;
            Map<String, dynamic> attendanceData = attendanceDoc.data() as Map<String, dynamic>;
            
            attendedInstances.add({
              'instanceId': instanceId,
              'instanceData': instanceData,
              'attendanceData': attendanceData,
            });
          }
        }

        // Only add event if user attended at least one instance
        if (attendedInstances.isNotEmpty) {
          eventsWithAttendance.add({
            'eventId': eventId,
            'eventData': eventData,
            'attendedInstances': attendedInstances,
          });
        }
      }

      // Sort events by the event start date (most recent first)
      eventsWithAttendance.sort((a, b) {
        DateTime? aStartDate = _getEventStartDate(a['eventData']);
        DateTime? bStartDate = _getEventStartDate(b['eventData']);
        
        if (aStartDate == null && bStartDate == null) return 0;
        if (aStartDate == null) return 1;
        if (bStartDate == null) return -1;
        
        return bStartDate.compareTo(aStartDate);
      });

      setState(() {
        attendedEvents = eventsWithAttendance;
        isLoadingAttendance = false;
      });
    } catch (e) {
      print('Error loading attendance history: $e');
      setState(() {
        isLoadingAttendance = false;
      });
    }
  }

  DateTime? _getEventStartDate(Map<String, dynamic> eventData) {
    if (eventData.containsKey('startDate') && eventData['startDate'] != null) {
      Timestamp timestamp = eventData['startDate'] as Timestamp;
      return timestamp.toDate();
    }
    return null;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _switchToAttendanceHistory() {
    setState(() {
      _currentTabIndex = 1;
    });
    if (attendedEvents.isEmpty && !isLoadingAttendance) {
      _loadAttendanceHistory();
    }
  }

  void _switchToHome() {
    setState(() {
      _currentTabIndex = 0;
    });
  }

  void _showInstanceSelectionModal() {
    if (upcomingEventDetails != null && upcomingEventDetails!['eventId'] != null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return InstanceSelectionModal(
            eventId: upcomingEventDetails!['eventId'],
            eventDetails: upcomingEventDetails!,
          );
        },
      );
    }
  }

  void _showUserPopup() {
    if (isShowingUserPopup) return;

    setState(() {
      isShowingUserPopup = true;
    });

    _overlayEntry = OverlayEntry(
      builder: (context) => UserAccountPopup(
        onClose: _hideUserPopup,
        onLogout: _handleLogoutFromDashboard,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideUserPopup() {
    if (!isShowingUserPopup) return;

    setState(() {
      isShowingUserPopup = false;
    });

    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _handleLogoutFromDashboard() {
    // Navigate to landing page from dashboard context
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/landing',
      (Route<dynamic> route) => false,
    );
  }

  void _showAttendanceInstancesModal(Map<String, dynamic> eventData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AttendanceInstancesModal(
          eventData: eventData,
          userId: currentUserId!,
        );
      },
    );
  }

  @override
  void dispose() {
    _hideUserPopup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Fixed top bar - always visible
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildTopBar(),
              ),
            ),
          ),
          
          // Content area based on current tab
          Expanded(
            child: _currentTabIndex == 0 
                ? _buildHomeContent()
                : _buildAttendanceHistoryContent(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildHomeContent() {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: RefreshIndicator(
        onRefresh: _loadEventData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Get started section
              _buildGetStartedSection(),
              const SizedBox(height: 24),
              
              // Explore section
              _buildExploreSection(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceHistoryContent() {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: isLoadingAttendance
          ? const Center(child: CircularProgressIndicator())
          : attendedEvents.isEmpty
              ? _buildAttendanceEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadAttendanceHistory,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 5),
                        // Title for attendance history
                        const Text(
                          'Attendance History',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Event cards
                        ...attendedEvents.map((eventData) => _buildEventCard(eventData)).toList(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildTopBar() {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final photoURL = user?.photoURL;
        
        return Row(
          children: [
            // Grid icon
            Container(
              padding: const EdgeInsets.all(8),
              child: const Icon(
                Icons.apps,
                color: Colors.black87,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            
            // Search bar
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 16),
                    Icon(Icons.search, color: Colors.grey, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Search',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Notification bell with red badge
            Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.black87,
                    size: 20,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            
            // User profile circle - now clickable
            GestureDetector(
              onTap: () {
                if (isShowingUserPopup) {
                  _hideUserPopup();
                } else {
                  _showUserPopup();
                }
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isShowingUserPopup ? Colors.purple : Colors.grey[300]!,
                    width: isShowingUserPopup ? 2 : 1,
                  ),
                ),
                child: ClipOval(
                  child: photoURL != null && photoURL.isNotEmpty
                      ? Image.network(
                          photoURL,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[100],
                              child: const Icon(
                                Icons.person,
                                color: Colors.grey,
                                size: 20,
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[100],
                              child: const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[100],
                          child: const Icon(
                            Icons.person,
                            color: Colors.grey,
                            size: 20,
                          ),
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGetStartedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Get started',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text(
                'How to use',
                style: TextStyle(
                  color: Colors.purple,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        GestureDetector(
          onTap: () {
            // Show modal only if there's event data or when showing "no activities"
            if (upcomingEventDetails != null || !isLoading) {
              _showEventDetailsModal(context);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isLoading 
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Upcoming Activity',
                        style: TextStyle(
                          color: Colors.purple,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  upcomingEventDetails?['eventName'] ?? 'No upcoming activities yet',
                                  style: const TextStyle(
                                    fontSize: 25,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                    height: 1.2,
                                  ),
                                ),
                                
                                if (upcomingEventDetails != null && upcomingEventDetails!['eventName'] != 'No upcoming activities yet') ...[
                                  const SizedBox(height: 16),
                                  
                                  // Location
                                  if (upcomingEventDetails!['locationText'].isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.location_on_outlined,
                                            size: 16,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              upcomingEventDetails!['locationText'],
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  
                                  // Date and time
                                  if (upcomingEventDetails!['dateTimeText'].isNotEmpty)
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.schedule_outlined,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          upcomingEventDetails!['dateTimeText'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                ] else if (!isLoading) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    'No upcoming activities yet',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          
                          // Button and status column
                          Column(
                            children: [
                              GestureDetector(
                                onTap: (upcomingEventDetails?['canCast'] == true && upcomingEventDetails?['eventName'] != 'No upcoming activities yet') 
                                    ? () {
                                        _showInstanceSelectionModal();
                                      }
                                    : null,
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    gradient: (upcomingEventDetails?['canCast'] == true && upcomingEventDetails?['eventName'] != 'No upcoming activities yet')
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
                                    boxShadow: [
                                      BoxShadow(
                                        color: (upcomingEventDetails?['canCast'] == true && upcomingEventDetails?['eventName'] != 'No upcoming activities yet')
                                            ? Colors.purple.withOpacity(0.3)
                                            : Colors.grey.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                              
                              // Status message below the button
                              if (upcomingEventDetails != null && upcomingEventDetails!['eventName'] != 'No upcoming activities yet') ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: 80, // Constrain width to keep it aligned with button
                                  child: Text(
                                    upcomingEventDetails!['statusMessage'],
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: upcomingEventDetails!['canCast'] == true 
                                          ? Colors.purple 
                                          : Colors.grey[600],
                                      fontWeight: upcomingEventDetails!['canCast'] == true 
                                          ? FontWeight.w600 
                                          : FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildExploreSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Explore Proximicast',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        
        GestureDetector(
          onTap: _switchToAttendanceHistory,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Show your recent attendances',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Check whether you are present or absent in a specific event.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 65,
                  height: 65,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.yellow, Colors.orange],
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'images/proximicast_icon3.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No attendance history',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You haven\'t attended any events yet',
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

  Widget _buildEventCard(Map<String, dynamic> eventData) {
    Map<String, dynamic> event = eventData['eventData'];
    List<Map<String, dynamic>> attendedInstances = eventData['attendedInstances'];
    DateTime? eventStartDate = _getEventStartDate(event);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        child: InkWell(
          onTap: () => _showAttendanceInstancesModal(eventData),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
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
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${attendedInstances.length} attended',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.purple,
                        ),
                      ),
                    ),
                  ],
                ),
                
                if (event['description'] != null && event['description'].isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    event['description'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event['locationText'] ?? 'No location specified',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 4),
                
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      eventStartDate != null 
                          ? 'Event date: ${_formatDate(eventStartDate)}'
                          : 'No event date available',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Tap to view details',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.purple[300],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Colors.purple[300],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEventDetailsModal(BuildContext context) async {
    // Get full event details including description
    Map<String, dynamic> modalEventDetails = {};
    
    if (upcomingEventDetails != null && upcomingEventDetails!['eventName'] != 'No upcoming activities yet') {
      try {
        // Get event details from database
        final events = await DatabaseService.getAllEvents();
        final event = events.firstWhere(
          (e) => e['id'] == upcomingEventDetails!['eventId'],
          orElse: () => <String, dynamic>{},
        );
        
        modalEventDetails = {
          ...upcomingEventDetails!,
          'description': event.isNotEmpty ? event['description'] : 'No description available',
        };
      } catch (e) {
        print('Error getting event description: $e');
        modalEventDetails = {
          ...upcomingEventDetails!,
          'description': 'Description not available',
        };
      }
    } else {
      // No upcoming events case
      modalEventDetails = {
        'eventName': 'No upcoming activities yet',
        'description': '',
        'locationText': '',
        'dateTimeText': '',
        'statusMessage': '',
        'canCast': false,
        'eventId': null,
      };
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return EventDetailsModal(eventDetails: modalEventDetails);
      },
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home, _currentTabIndex == 0, _switchToHome),
          _buildNavItem(Icons.history, _currentTabIndex == 1, _switchToAttendanceHistory),
          _buildNavItem(Icons.receipt_long, false, null),
          _buildNavItem(Icons.account_circle_outlined, false, null),
          _buildNavItem(Icons.bar_chart, false, null),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, bool isActive, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Icon(
          icon,
          size: 24,
          color: isActive ? Colors.blue : Colors.grey,
        ),
      ),
    );
  }
}


