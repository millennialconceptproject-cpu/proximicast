import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  static Database? _database;
  static const String _dbName = 'proximicast_local.db';
  static const int _dbVersion = 1;
  
  // Table name
  static const String _usersTable = 'users';

  // Get database instance
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize database
  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createTables,
    );
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
  }

  // Insert or update user data
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

    // Check if user already exists
    List<Map<String, dynamic>> existingUser = await db.query(
      _usersTable,
      where: 'uid = ?',
      whereArgs: [uid],
    );

    if (existingUser.isEmpty) {
      // Insert new user
      userData['createdAt'] = now;
      await db.insert(_usersTable, userData);
      print('New user inserted into local database: $uid');
    } else {
      // Update existing user
      await db.update(
        _usersTable,
        userData,
        where: 'uid = ?',
        whereArgs: [uid],
      );
      print('User updated in local database: $uid');
    }
  }

  // Get user data by UID
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

  // Check if user exists in local database
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

  // Get all users (for debugging purposes)
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return await db.query(_usersTable);
  }

  // Delete user data
  static Future<void> deleteUser(String uid) async {
    final db = await database;
    await db.delete(
      _usersTable,
      where: 'uid = ?',
      whereArgs: [uid],
    );
    print('User deleted from local database: $uid');
  }

  // Clear all user data (for sign out)
  static Future<void> clearAllUsers() async {
    final db = await database;
    await db.delete(_usersTable);
    print('All users cleared from local database');
  }

  // Fetch user data from Firestore and store locally
  static Future<void> fetchAndStoreUserFromFirestore(String uid) async {
    try {
      print('Fetching user data from Firestore for UID: $uid');
      
      // Get user document from Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('User document not found in Firestore');
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      
      // Extract personal and academic info
      Map<String, dynamic>? personalInfo = userData['personalInfo'];
      Map<String, dynamic>? academicInfo = userData['academicInfo'];

      if (personalInfo == null || academicInfo == null) {
        throw Exception('Incomplete user data in Firestore');
      }

      // Store in local database
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

  // Sync user data from local to Firestore (if needed)
  static Future<void> syncUserDataToFirestore(String uid) async {
    try {
      Map<String, dynamic>? localUser = await getUserByUid(uid);
      if (localUser == null) {
        throw Exception('User not found in local database');
      }

      // Prepare data for Firestore
      Map<String, dynamic> firestoreData = {
        'email': localUser['email'],
        'displayName': localUser['displayName'],
        'photoURL': localUser['photoURL'],
        'personalInfo': {
          'firstName': localUser['firstName'],
          'lastName': localUser['lastName'],
          'middleName': localUser['middleName'],
          'contactNumber': '', // You might want to add this to local DB too
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

  // Database maintenance methods
  static Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // Get database info for debugging
  static Future<Map<String, dynamic>> getDatabaseInfo() async {
    final db = await database;
    final users = await getAllUsers();
    return {
      'dbPath': db.path,
      'userCount': users.length,
      'users': users,
    };
  }
}