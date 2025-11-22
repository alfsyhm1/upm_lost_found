import 'package:latlong2/latlong.dart';
import '../models/faculty_model.dart';

// Graph representing UPM Faculties
// Weights are approximate distances in km
final Map<String, List<Edge>> graph = {
  "FSKTM": [Edge("FP", 0.5), Edge("Library", 0.8)],
  "FP": [Edge("FSKTM", 0.5), Edge("FEP", 0.4), Edge("Library", 1.0)],
  "FEP": [Edge("FP", 0.4), Edge("FPP", 0.6)],
  "FPP": [Edge("FEP", 0.6), Edge("Library", 1.2)],
  "Library": [Edge("FSKTM", 0.8), Edge("FP", 1.0), Edge("FPP", 1.2)],
};

class Edge {
  final String to;
  final double weight;
  Edge(this.to, this.weight);
}

// --- Helper Functions Required by Report Screen ---

// Get Faculty Name by ID
String getFacultyName(String id) {
  try {
    final node = facultyNodes.firstWhere((n) => n.id == id);
    return node.name;
  } catch (e) {
    return "Unknown Location";
  }
}

// Find nearest faculty to a coordinate
String findNearestFacultyId(LatLng point) {
  if (facultyNodes.isEmpty) return "FSKTM"; // Default fallback

  double minDistance = double.infinity;
  String nearestId = facultyNodes.first.id;

  for (var node in facultyNodes) {
    // Simple distance calculation (abs diff)
    double dist = (point.latitude - node.latitude).abs() + 
                  (point.longitude - node.longitude).abs();
    if (dist < minDistance) {
      minDistance = dist;
      nearestId = node.id;
    }
  }
  return nearestId;
}

// --- Dijkstra Algorithm ---

List<String> dijkstra(String start, String end) {
  final dist = <String, double>{};
  final prev = <String, String?>{};
  final unvisited = <String>{};

  // Initialize
  for (var node in graph.keys) {
    dist[node] = double.infinity;
    prev[node] = null;
    unvisited.add(node);
  }
  
  // Fallback if start/end not in graph
  if (!graph.containsKey(start)) {
    // If start node isn't in graph, try to map it to FSKTM or add logic
    dist["FSKTM"] = 0; 
  } else {
    dist[start] = 0;
  }

  while (unvisited.isNotEmpty) {
    // Get node with smallest distance
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