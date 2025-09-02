import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String name;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> locationIds;
  final int notifyDaysBefore;
  final DateTime createdAt;
  final DateTime updatedAt;

  Event({
    required this.id,
    required this.name,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.locationIds,
    required this.notifyDaysBefore,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Event.fromFirestore(Map<String, dynamic> data, String id) {
    return Event(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      locationIds: List<String>.from(data['locationIds'] ?? []),
      notifyDaysBefore: data['notifyDaysBefore'] ?? 1,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'locationIds': locationIds.join(','),
      'notifyDaysBefore': notifyDaysBefore,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      locationIds: map['locationIds'].split(',').where((s) => s.isNotEmpty).toList(),
      notifyDaysBefore: map['notifyDaysBefore'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }
}

class Location {
  final String id;
  final String locationName;
  final String barangay;
  final String city;
  final String province;
  final String street;

  Location({
    required this.id,
    required this.locationName,
    required this.barangay,
    required this.city,
    required this.province,
    required this.street,
  });

  factory Location.fromFirestore(Map<String, dynamic> data, String id) {
    return Location(
      id: id,
      locationName: data['locationName'] ?? '',
      barangay: data['barangay'] ?? '',
      city: data['city'] ?? '',
      province: data['province'] ?? '',
      street: data['street'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'locationName': locationName,
      'barangay': barangay,
      'city': city,
      'province': province,
      'street': street,
    };
  }

  factory Location.fromMap(Map<String, dynamic> map) {
    return Location(
      id: map['id'],
      locationName: map['locationName'],
      barangay: map['barangay'],
      city: map['city'],
      province: map['province'],
      street: map['street'],
    );
  }
}