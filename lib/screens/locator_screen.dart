import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/item_model.dart';
import 'item_detail_screen.dart';

class LocatorScreen extends StatefulWidget {
  const LocatorScreen({super.key});

  @override
  State<LocatorScreen> createState() => _LocatorScreenState();
}

class _LocatorScreenState extends State<LocatorScreen> {
  final MapController _mapController = MapController();
  List<Item> _items = [];
  List<Item> _filteredItems = [];
  double _currentZoom = 15.0;

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    final data = await Supabase.instance.client.from('items').select();
    setState(() {
      _items = (data as List).map((e) => Item.fromMap(e)).toList();
      _filteredItems = _items;
    });
  }

  void _filterItems(String query) {
    setState(() {
      _filteredItems = _items.where((i) => 
        i.title.toLowerCase().contains(query.toLowerCase()) || 
        i.locationName.toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }

  void _zoom(double change) {
    _currentZoom = (_currentZoom + change).clamp(10.0, 18.0);
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  Future<void> _goToMyLocation() async {
    Position pos = await Geolocator.getCurrentPosition();
    _mapController.move(LatLng(pos.latitude, pos.longitude), 16.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: LatLng(2.9926, 101.7079), initialZoom: _currentZoom),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.upm.lostfound',
              ),
              MarkerLayer(
                markers: _filteredItems.where((i) => i.locationLat != null).map((item) {
                  return Marker(
                    point: LatLng(item.locationLat!, item.locationLng!),
                    width: 40, height: 40,
                    child: GestureDetector(
                      onTap: () => _showPreview(item),
                      child: Icon(Icons.location_pin, color: item.type == 'lost' ? Colors.red : Colors.blue, size: 40),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          
          // Search Bar
          Positioned(
            top: 50, left: 15, right: 15,
            child: Card(
              elevation: 4,
              child: TextField(
                decoration: const InputDecoration(
                  hintText: "Search items or location...",
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(15),
                ),
                onChanged: _filterItems,
              ),
            ),
          ),

          // Zoom & Location Controls
          Positioned(
            bottom: 100, right: 15,
            child: Column(
              children: [
                FloatingActionButton.small(heroTag: "z+", onPressed: () => _zoom(1), child: const Icon(Icons.add)),
                const SizedBox(height: 10),
                FloatingActionButton.small(heroTag: "z-", onPressed: () => _zoom(-1), child: const Icon(Icons.remove)),
                const SizedBox(height: 10),
                FloatingActionButton(heroTag: "loc", onPressed: _goToMyLocation, child: const Icon(Icons.my_location)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPreview(Item item) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        height: 180,
        child: Column(
          children: [
            Text(item.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(item.locationName),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item))),
              child: const Text("View Details"),
            )
          ],
        ),
      )
    );
  }
}