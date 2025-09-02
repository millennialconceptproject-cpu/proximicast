import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import for GeoPoint

class GeofencingService {
  /// Determines if a point is inside a polygon using the ray casting algorithm
  /// 
  /// [point] - The point to test (user's location)
  /// [polygon] - List of LatLng points representing the polygon vertices
  /// 
  /// Returns true if the point is inside the polygon, false otherwise
  static bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) {
      // A polygon must have at least 3 points
      return false;
    }

    int intersectCount = 0;
    final double x = point.longitude;
    final double y = point.latitude;

    for (int i = 0; i < polygon.length; i++) {
      final LatLng vertex1 = polygon[i];
      final LatLng vertex2 = polygon[(i + 1) % polygon.length];

      // Check if the ray from the point intersects with the edge
      if (_rayIntersectsSegment(x, y, vertex1, vertex2)) {
        intersectCount++;
      }
    }

    // If the number of intersections is odd, the point is inside
    return intersectCount % 2 == 1;
  }

  /// Helper method to determine if a horizontal ray from point (x, y) intersects
  /// with a line segment defined by vertex1 and vertex2
  static bool _rayIntersectsSegment(double x, double y, LatLng vertex1, LatLng vertex2) {
    final double x1 = vertex1.longitude;
    final double y1 = vertex1.latitude;
    final double x2 = vertex2.longitude;
    final double y2 = vertex2.latitude;

    // Check if the ray is above or below both vertices
    if ((y1 > y) == (y2 > y)) {
      return false;
    }

    // Calculate the x-coordinate of the intersection
    final double intersectionX = x1 + (y - y1) / (y2 - y1) * (x2 - x1);

    // Check if the intersection is to the right of the point
    return x < intersectionX;
  }

  /// Calculate the distance between two LatLng points in meters
  static double calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, point1, point2);
  }

  /// Check if a point is within a certain distance of any polygon vertex
  /// Useful for handling edge cases or providing buffer zones
  static bool isPointNearPolygon(LatLng point, List<LatLng> polygon, double bufferMeters) {
    for (LatLng vertex in polygon) {
      if (calculateDistance(point, vertex) <= bufferMeters) {
        return true;
      }
    }
    return false;
  }

  /// Get the center point of a polygon (centroid)
  static LatLng getPolygonCenter(List<LatLng> polygon) {
    if (polygon.isEmpty) {
      return const LatLng(0, 0);
    }

    double totalLat = 0;
    double totalLng = 0;

    for (LatLng point in polygon) {
      totalLat += point.latitude;
      totalLng += point.longitude;
    }

    return LatLng(
      totalLat / polygon.length,
      totalLng / polygon.length,
    );
  }

  /// Parse coordinate string format "[9.9139° N, 123.922409° E]" to LatLng
  static LatLng? parseCoordinateString(String coordString) {
    try {
      final latLngMatch = RegExp(r'\[([0-9.]+)° N, ([0-9.]+)° E\]').firstMatch(coordString);
      if (latLngMatch != null) {
        final lat = double.parse(latLngMatch.group(1)!);
        final lng = double.parse(latLngMatch.group(2)!);
        return LatLng(lat, lng);
      }
      return null;
    } catch (e) {
      print('Error parsing coordinate string: $coordString - $e');
      return null;
    }
  }

  /// Parse a list of coordinate objects (GeoPoint, String, or Map) to LatLng points
  static List<LatLng> parseCoordinates(List<dynamic> coordinates) {
    List<LatLng> points = [];
    
    for (var coord in coordinates) {
      // Handle GeoPoint objects from Firestore
      if (coord is GeoPoint) {
        points.add(LatLng(coord.latitude, coord.longitude));
      }
      // Handle string coordinates
      else if (coord is String) {
        final latLng = parseCoordinateString(coord);
        if (latLng != null) {
          points.add(latLng);
        }
      }
      // Handle Map objects
      else if (coord is Map<String, dynamic>) {
        if (coord.containsKey('latitude') && coord.containsKey('longitude')) {
          final lat = coord['latitude'] as double;
          final lng = coord['longitude'] as double;
          points.add(LatLng(lat, lng));
        }
      }
    }
    
    return points;
  }

  /// Validate if a polygon has at least 3 points and forms a closed shape
  static bool isValidPolygon(List<LatLng> polygon) {
    if (polygon.length < 3) {
      return false;
    }

    // Check if first and last points are the same (closed polygon)
    // If not, it's still valid as we can close it programmatically
    return true;
  }

  /// Close a polygon by ensuring the last point equals the first point
  static List<LatLng> closePolygon(List<LatLng> polygon) {
    if (polygon.isEmpty) return polygon;
    
    final List<LatLng> closedPolygon = List.from(polygon);
    
    // Check if polygon is already closed
    if (closedPolygon.first.latitude != closedPolygon.last.latitude ||
        closedPolygon.first.longitude != closedPolygon.last.longitude) {
      closedPolygon.add(closedPolygon.first);
    }
    
    return closedPolygon;
  }

  /// Debug method to print polygon information
  static void debugPolygonInfo(List<LatLng> polygon, String label) {
    print('=== $label POLYGON DEBUG ===');
    print('Polygon has ${polygon.length} points');
    print('Is valid: ${isValidPolygon(polygon)}');
    
    if (polygon.isNotEmpty) {
      print('Center: ${getPolygonCenter(polygon)}');
      print('Points:');
      for (int i = 0; i < polygon.length; i++) {
        print('  [$i]: ${polygon[i]}');
      }
    }
    print('========================');
  }
}