import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  static Database? _database;
  static const String _dbName = 'proximicast_local.db';
  static const int _dbVersion = 2; // Updated version for new tables
  
  // Table names
  static const String _usersTable = 'users';
  static const String _eventsTable = 'events';
  static const String _locationsTable = 'locations';

  // Get database instance
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static String? getCurrentUserId() {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  // Initialize database
  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  // Handle database upgrades
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createEventsTable(db);
      await _createLocationsTable(db);
    }
  }

  // Create tables
  static Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_usersTable (
        uid TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        firstName TEXT NOT NULL,
        lastName TEXT NOT NULL,
        middleName TEXT,
        studentIdNumber TEXT NOT NULL,
        program TEXT NOT NULL,
        year TEXT NOT NULL,
        block TEXT NOT NULL,
        displayName TEXT,
        photoURL TEXT,
        createdAt TEXT NOT NULL,
        lastUpdated TEXT NOT NULL
      )
    ''');

    await _createEventsTable(db);
    await _createLocationsTable(db);
  }

  static Future<void> _createEventsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_eventsTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT NOT NULL,
        locationIds TEXT NOT NULL,
        notifyDaysBefore INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _createLocationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_locationsTable (
        id TEXT PRIMARY KEY,
        locationName TEXT NOT NULL,
        barangay TEXT NOT NULL,
        city TEXT NOT NULL,
        province TEXT NOT NULL,
        street TEXT NOT NULL
      )
    ''');
  }

  // User methods
  static Future<void> insertOrUpdateUser({
    required String uid,
    required String email,
    required String firstName,
    required String lastName,
    String? middleName,
    required String studentIdNumber,
    required String program,
    required String year,
    required String block,
    String? displayName,
    String? photoURL,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    Map<String, dynamic> userData = {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'middleName': middleName ?? '',
      'studentIdNumber': studentIdNumber,
      'program': program,
      'year': year,
      'block': block,
      'displayName': displayName ?? '',
      'photoURL': photoURL ?? '',
      'lastUpdated': now,
    };

    List<Map<String, dynamic>> existingUser = await db.query(
      _usersTable,
      where: 'uid = ?',
      whereArgs: [uid],
    );

    if (existingUser.isEmpty) {
      userData['createdAt'] = now;
      await db.insert(_usersTable, userData);
      print('New user inserted into local database: $uid');
    } else {
      await db.update(
        _usersTable,
        userData,
        where: 'uid = ?',
        whereArgs: [uid],
      );
      print('User updated in local database: $uid');
    }
  }

  static Future<Map<String, dynamic>?> getUserByUid(String uid) async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      _usersTable,
      where: 'uid = ?',
      whereArgs: [uid],
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  static Future<bool> userExists(String uid) async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      _usersTable,
      where: 'uid = ?',
      whereArgs: [uid],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return await db.query(_usersTable);
  }

  static Future<void> deleteUser(String uid) async {
    final db = await database;
    await db.delete(
      _usersTable,
      where: 'uid = ?',
      whereArgs: [uid],
    );
    print('User deleted from local database: $uid');
  }

  static Future<void> clearAllUsers() async {
    final db = await database;
    await db.delete(_usersTable);
    print('All users cleared from local database');
  }

  // Event methods
  static Future<void> insertOrUpdateEvent(Map<String, dynamic> eventData) async {
    final db = await database;
    
    List<Map<String, dynamic>> existingEvent = await db.query(
      _eventsTable,
      where: 'id = ?',
      whereArgs: [eventData['id']],
    );

    if (existingEvent.isEmpty) {
      await db.insert(_eventsTable, eventData);
      print('New event inserted into local database: ${eventData['id']}');
    } else {
      await db.update(
        _eventsTable,
        eventData,
        where: 'id = ?',
        whereArgs: [eventData['id']],
      );
      print('Event updated in local database: ${eventData['id']}');
    }
  }

  static Future<List<Map<String, dynamic>>> getAllEvents() async {
    final db = await database;
    return await db.query(_eventsTable, orderBy: 'startDate ASC');
  }

  static Future<Map<String, dynamic>?> getUpcomingEvent() async {
    final db = await database;
    final now = DateTime.now();
    
    // Get events that haven't ended yet
    List<Map<String, dynamic>> events = await db.query(
      _eventsTable,
      where: 'endDate >= ?',
      whereArgs: [now.toIso8601String()],
      orderBy: 'startDate ASC',
      limit: 1,
    );

    if (events.isNotEmpty) {
      return events.first;
    }
    return null;
  }

  // Location methods
  static Future<void> insertOrUpdateLocation(Map<String, dynamic> locationData) async {
    final db = await database;
    
    List<Map<String, dynamic>> existingLocation = await db.query(
      _locationsTable,
      where: 'id = ?',
      whereArgs: [locationData['id']],
    );

    if (existingLocation.isEmpty) {
      await db.insert(_locationsTable, locationData);
      print('New location inserted into local database: ${locationData['id']}');
    } else {
      await db.update(
        _locationsTable,
        locationData,
        where: 'id = ?',
        whereArgs: [locationData['id']],
      );
      print('Location updated in local database: ${locationData['id']}');
    }
  }

  static Future<List<Map<String, dynamic>>> getLocationsByIds(List<String> locationIds) async {
    final db = await database;
    if (locationIds.isEmpty) return [];
    
    String placeholders = locationIds.map((_) => '?').join(',');
    return await db.query(
      _locationsTable,
      where: 'id IN ($placeholders)',
      whereArgs: locationIds,
    );
  }

  // METHODS FOR ATTENDANCE SYSTEM (READ-ONLY)
  
  /// Get all instances for a specific event from Firestore
  static Future<List<Map<String, dynamic>>> getEventInstances(String eventId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('instances')
          .orderBy('startTime', descending: false)
          .get();

      return querySnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('Error getting event instances: $e');
      throw e;
    }
  }

  /// Get a specific event by ID from Firestore
  static Future<Map<String, dynamic>> getEventFromFirestore(String eventId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .get();

      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      } else {
        throw Exception('Event not found');
      }
    } catch (e) {
      print('Error getting event from Firestore: $e');
      throw e;
    }
  }

  /// Get a specific location by ID from Firestore
  static Future<Map<String, dynamic>> getLocationFromFirestore(String locationId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('locations')
          .doc(locationId)
          .get();

      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      } else {
        throw Exception('Location not found');
      }
    } catch (e) {
      print('Error getting location from Firestore: $e');
      throw e;
    }
  }

  // Sync methods
  static Future<void> fetchAndStoreEventsFromFirestore() async {
    try {
      print('Fetching events from Firestore...');
      
      QuerySnapshot eventsSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .get();

      for (QueryDocumentSnapshot doc in eventsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        Map<String, dynamic> eventData = {
          'id': doc.id,
          'name': data['name'] ?? '',
          'description': data['description'] ?? '',
          'startDate': (data['startDate'] as Timestamp).toDate().toIso8601String(),
          'endDate': (data['endDate'] as Timestamp).toDate().toIso8601String(),
          'locationIds': (data['locationIds'] as List).join(','),
          'notifyDaysBefore': data['notifyDaysBefore'] ?? 1,
          'createdAt': (data['createdAt'] as Timestamp).toDate().toIso8601String(),
          'updatedAt': (data['updatedAt'] as Timestamp).toDate().toIso8601String(),
        };

        await insertOrUpdateEvent(eventData);
      }

      print('Events successfully fetched from Firestore and stored locally');
    } catch (e) {
      print('Error fetching events from Firestore: $e');
      throw e;
    }
  }

  static Future<void> fetchAndStoreLocationsFromFirestore() async {
    try {
      print('Fetching locations from Firestore...');
      
      QuerySnapshot locationsSnapshot = await FirebaseFirestore.instance
          .collection('locations')
          .get();

      for (QueryDocumentSnapshot doc in locationsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        Map<String, dynamic> locationData = {
          'id': doc.id,
          'locationName': data['locationName'] ?? '',
          'barangay': data['barangay'] ?? '',
          'city': data['city'] ?? '',
          'province': data['province'] ?? '',
          'street': data['street'] ?? '',
        };

        await insertOrUpdateLocation(locationData);
      }

      print('Locations successfully fetched from Firestore and stored locally');
    } catch (e) {
      print('Error fetching locations from Firestore: $e');
      throw e;
    }
  }

  static Future<void> fetchAndStoreUserFromFirestore(String uid) async {
    try {
      print('Fetching user data from Firestore for UID: $uid');
      
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('User document not found in Firestore');
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      
      Map<String, dynamic>? personalInfo = userData['personalInfo'];
      Map<String, dynamic>? academicInfo = userData['academicInfo'];

      if (personalInfo == null || academicInfo == null) {
        throw Exception('Incomplete user data in Firestore');
      }

      await insertOrUpdateUser(
        uid: uid,
        email: userData['email'] ?? '',
        firstName: personalInfo['firstName'] ?? '',
        lastName: personalInfo['lastName'] ?? '',
        middleName: personalInfo['middleName'],
        studentIdNumber: academicInfo['idNumber'] ?? '',
        program: academicInfo['program'] ?? '',
        year: academicInfo['year'] ?? '',
        block: academicInfo['block'] ?? '',
        displayName: userData['displayName'],
        photoURL: userData['photoURL'],
      );

      print('User data successfully fetched from Firestore and stored locally');
    } catch (e) {
      print('Error fetching user data from Firestore: $e');
      throw e;
    }
  }

  static Future<void> syncUserDataToFirestore(String uid) async {
    try {
      Map<String, dynamic>? localUser = await getUserByUid(uid);
      if (localUser == null) {
        throw Exception('User not found in local database');
      }

      Map<String, dynamic> firestoreData = {
        'email': localUser['email'],
        'displayName': localUser['displayName'],
        'photoURL': localUser['photoURL'],
        'personalInfo': {
          'firstName': localUser['firstName'],
          'lastName': localUser['lastName'],
          'middleName': localUser['middleName'],
          'contactNumber': '',
        },
        'academicInfo': {
          'idNumber': localUser['studentIdNumber'],
          'program': localUser['program'],
          'year': localUser['year'],
          'block': localUser['block'],
        },
        'lastSignIn': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(firestoreData, SetOptions(merge: true));

      print('User data synced from local to Firestore');
    } catch (e) {
      print('Error syncing user data to Firestore: $e');
      throw e;
    }
  }

  // Clean up methods
  static Future<void> clearAllEvents() async {
    final db = await database;
    await db.delete(_eventsTable);
    print('All events cleared from local database');
  }

  static Future<void> clearAllLocations() async {
    final db = await database;
    await db.delete(_locationsTable);
    print('All locations cleared from local database');
  }

  static Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  static Future<Map<String, dynamic>> getDatabaseInfo() async {
    final db = await database;
    final users = await getAllUsers();
    final events = await getAllEvents();
    return {
      'dbPath': db.path,
      'userCount': users.length,
      'eventCount': events.length,
      'users': users,
      'events': events,
    };
  }

  /// Store attendance record in instance subcollection with user information
  static Future<void> storeAttendanceRecord({
    required String eventId,
    required String instanceId,
    required String userId,
    required String eventName,
    required String instanceName,
    required String locationId,
    required String locationName,
    required String status,
    required DateTime timeAttended,
    required double userLatitude,
    required double userLongitude,
  }) async {
    try {
      // Fetch user information from local database
      final localUserData = await getUserByUid(userId);
      if (localUserData == null) {
        throw Exception('User data not found in local database');
      }

      final attendanceData = {
        'userId': userId,
        'eventId': eventId,
        'eventName': eventName,
        'instanceId': instanceId,
        'instanceName': instanceName,
        'locationId': locationId,
        'locationName': locationName,
        'status': status,
        'timeAttended': Timestamp.fromDate(timeAttended),
        'userLocation': {
          'latitude': userLatitude,
          'longitude': userLongitude,
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

      // Store in events/{eventId}/instances/{instanceId}/attendance/{userId}
      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('instances')
          .doc(instanceId)
          .collection('attendance')
          .doc(userId)
          .set(attendanceData, SetOptions(merge: true));

      print('Attendance record stored successfully with user information');
      print('User: ${localUserData['firstName']} ${localUserData['lastName']} (${localUserData['studentIdNumber']})');
      print('Program: ${localUserData['program']} - ${localUserData['year']} ${localUserData['block']}');
    } catch (e) {
      print('Error storing attendance record: $e');
      throw e;
    }
  }

  /// Check if user has already recorded attendance for this instance
  static Future<bool> hasUserAttendedInstance(String eventId, String instanceId, String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('instances')
          .doc(instanceId)
          .collection('attendance')
          .doc(userId)
          .get();

      return doc.exists;
    } catch (e) {
      print('Error checking user attendance: $e');
      return false;
    }
  }

  /// Get user's attendance record for a specific instance
  static Future<Map<String, dynamic>?> getUserAttendanceRecord(String eventId, String instanceId, String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('instances')
          .doc(instanceId)
          .collection('attendance')
          .doc(userId)
          .get();

      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }
      return null;
    } catch (e) {
      print('Error getting user attendance record: $e');
      throw e;
    }
  }

  /// Get all attendance records for a specific instance (Admin use)
  static Future<List<Map<String, dynamic>>> getInstanceAttendanceRecords(String eventId, String instanceId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('instances')
          .doc(instanceId)
          .collection('attendance')
          .orderBy('timeAttended', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('Error getting instance attendance records: $e');
      throw e;
    }
  }

  /// Get attendance statistics for an instance
  static Future<Map<String, int>> getInstanceAttendanceStats(String eventId, String instanceId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('instances')
          .doc(instanceId)
          .collection('attendance')
          .get();

      int totalAttendance = querySnapshot.docs.length;
      int presentCount = 0;
      int absentCount = 0;

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data['status'] == 'Present') {
          presentCount++;
        } else if (data['status'] == 'Absent') {
          absentCount++;
        }
      }

      return {
        'total': totalAttendance,
        'present': presentCount,
        'absent': absentCount,
      };
    } catch (e) {
      print('Error getting attendance stats: $e');
      throw e;
    }
  }

  /// Delete attendance record (if needed)
  static Future<void> deleteAttendanceRecord(String eventId, String instanceId, String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('instances')
          .doc(instanceId)
          .collection('attendance')
          .doc(userId)
          .delete();

      print('Attendance record deleted successfully');
    } catch (e) {
      print('Error deleting attendance record: $e');
      throw e;
    }
  }
}