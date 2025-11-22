import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/faculty_model.dart';
import '../services/dijkstra_service.dart';

class RouteMap extends StatefulWidget {
  final String startId;
  final String endId;

  const RouteMap({super.key, required this.startId, required this.endId});

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  List<LatLng> pathPoints = [];

  @override
  void initState() {
    super.initState();
    _calculateRoute();
  }

  void _calculateRoute() {
    // Get Dijkstra path (list of faculty IDs)
    List<String> path = dijkstra(widget.startId, widget.endId);

    // Convert faculty IDs to coordinates
    setState(() {
      pathPoints = path.map((id) {
        final node = facultyNodes.firstWhere((f) => f.id == id);
        return LatLng(node.latitude, node.longitude);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Suggested Drop-off Route"),
        backgroundColor: Colors.green.shade700,
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(2.9926, 101.7079),
          initialZoom: 15.0,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            userAgentPackageName: 'com.upm.lostandfound',
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: pathPoints,
                color: Colors.redAccent,
                strokeWidth: 5.0,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              if (pathPoints.isNotEmpty)
                Marker(
                  point: pathPoints.first,
                  width: 60,
                  height: 60,
                  child: const Icon(Icons.location_on,
                      color: Colors.blue, size: 40),
                ),
              if (pathPoints.length > 1)
                Marker(
                  point: pathPoints.last,
                  width: 60,
                  height: 60,
                  child: const Icon(Icons.flag, color: Colors.red, size: 40),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
