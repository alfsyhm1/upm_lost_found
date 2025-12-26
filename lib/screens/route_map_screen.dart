import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/faculty_model.dart';
import '../services/dijkstra_service.dart';

class RouteMapScreen extends StatefulWidget {
  final String destinationName;
  const RouteMapScreen({super.key, required this.destinationName});

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _calculateRoute();
  }

  void _calculateRoute() {
    FacultyNode? endNode;
    try {
      endNode = facultyNodes.firstWhere((n) => n.name == widget.destinationName);
    } catch (_) { return; }

    // Assume start at FSKTM for demo, or add geolocation logic here
    List<String> pathIds = dijkstra("FSKTM", endNode.id);
    
    setState(() {
      _routePoints = pathIds.map((id) {
        final node = facultyNodes.firstWhere((n) => n.id == id);
        return LatLng(node.latitude, node.longitude);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Route to Faculty")),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(initialCenter: const LatLng(2.9927, 101.7059), initialZoom: 15.0),
        children: [
          TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png"),
          PolylineLayer(polylines: [Polyline(points: _routePoints, strokeWidth: 5.0, color: Colors.blue)]),
          MarkerLayer(markers: _routePoints.map((p) => Marker(point: p, child: const Icon(Icons.location_pin, color: Colors.red))).toList()),
        ],
      ),
    );
  }
}