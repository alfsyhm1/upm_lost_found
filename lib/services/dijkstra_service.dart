import 'package:latlong2/latlong.dart';
import '../models/faculty_model.dart';

// Expanded Graph including Faculty of Science (FS)
final Map<String, List<Edge>> graph = {
  "FSKTM": [Edge("FP", 0.5), Edge("Library", 0.6)],
  "FP": [Edge("FSKTM", 0.5), Edge("SBE", 0.4), Edge("FS", 0.7)],
  "SBE": [Edge("FP", 0.4), Edge("FPP", 0.6)],
  "FPP": [Edge("SBE", 0.6), Edge("Library", 1.2)],
  "Library": [Edge("FSKTM", 0.6), Edge("FS", 0.5), Edge("FPP", 1.2)],
  "FS": [Edge("FP", 0.7), Edge("Library", 0.5)], // New Connections
};

class Edge {
  final String to;
  final double weight;
  Edge(this.to, this.weight);
}

// Helper: Get Faculty Name
String getFacultyName(String id) {
  try {
    return facultyNodes.firstWhere((n) => n.id == id).name;
  } catch (e) {
    return "Unknown Location";
  }
}

// Helper: Find Nearest Faculty from User's Location
String findNearestFacultyId(LatLng point) {
  if (facultyNodes.isEmpty) return "FSKTM";

  double minDistance = double.infinity;
  String nearestId = facultyNodes.first.id;

  for (var node in facultyNodes) {
    // Euclidean distance approximation
    double dist = (point.latitude - node.latitude).abs() + 
                  (point.longitude - node.longitude).abs();
    if (dist < minDistance) {
      minDistance = dist;
      nearestId = node.id;
    }
  }
  return nearestId;
}

// Dijkstra Algorithm (Standard)
List<String> dijkstra(String start, String end) {
  final dist = <String, double>{};
  final prev = <String, String?>{};
  final unvisited = <String>{};

  for (var node in graph.keys) {
    dist[node] = double.infinity;
    prev[node] = null;
    unvisited.add(node);
  }
  
  if (!graph.containsKey(start)) dist["FSKTM"] = 0; 
  else dist[start] = 0;

  while (unvisited.isNotEmpty) {
    String current = unvisited.reduce((a, b) => dist[a]! < dist[b]! ? a : b);
    
    if (dist[current] == double.infinity) break;
    unvisited.remove(current);
    if (current == end) break;

    if (graph.containsKey(current)) {
      for (var edge in graph[current]!) {
        if (unvisited.contains(edge.to)) {
          double alt = dist[current]! + edge.weight;
          if (alt < dist[edge.to]!) {
            dist[edge.to] = alt;
            prev[edge.to] = current;
          }
        }
      }
    }
  }

  final path = <String>[];
  String? u = end;
  if (prev[u] != null || u == start) {
    while (u != null) {
      path.insert(0, u);
      u = prev[u];
    }
  }
  return path;
}