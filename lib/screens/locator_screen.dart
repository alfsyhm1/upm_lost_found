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
  final TextEditingController _searchController = TextEditingController();
  LatLng _center = LatLng(2.9926, 101.7079); // UPM Default
  double _zoom = 15.0;
  List<Item> _allItems = [];
  List<Item> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    final data = await Supabase.instance.client.from('items').select();
    setState(() {
      _allItems = (data as List).map((e) => Item.fromMap(e)).toList();
      _filteredItems = _allItems;
    });
  }

  void _filterMap(String query) {
    setState(() {
      _filteredItems = _allItems.where((i) => 
        i.title.toLowerCase().contains(query.toLowerCase()) || 
        i.locationName.toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }

  Future<void> _goToCurrentLocation() async {
    Position pos = await Geolocator.getCurrentPosition();
    _mapController.move(LatLng(pos.latitude, pos.longitude), 16.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. The Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _center, initialZoom: _zoom),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.example.upm_lost_found',
              ),
              MarkerLayer(
                markers: _filteredItems.where((i) => i.locationLat != null).map((item) {
                  return Marker(
                    point: LatLng(item.locationLat!, item.locationLng!),
                    width: 50, height: 50,
                    child: GestureDetector(
                      onTap: () => showModalBottomSheet(context: context, builder: (_) => _PreviewSheet(item: item)),
                      child: Icon(Icons.location_pin, color: item.type == 'lost' ? Colors.red : Colors.blue, size: 50),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // 2. Search Bar (Top)
          Positioned(
            top: 50, left: 15, right: 15,
            child: Card(
              elevation: 5,
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: "Search location or item...",
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(15),
                ),
                onChanged: _filterMap,
              ),
            ),
          ),

          // 3. Controls (Right Side)
          Positioned(
            bottom: 100, right: 15,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: "zoomIn",
                  onPressed: () { _zoom++; _mapController.move(_mapController.camera.center, _zoom); },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: "zoomOut",
                  onPressed: () { _zoom--; _mapController.move(_mapController.camera.center, _zoom); },
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "myLoc",
                  onPressed: _goToCurrentLocation,
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewSheet extends StatelessWidget {
  final Item item;
  const _PreviewSheet({required this.item});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: 200,
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
    );
  }
}