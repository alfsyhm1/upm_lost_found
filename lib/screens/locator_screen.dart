import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; 
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
  
  List<Item> _items = [];
  List<Item> _filteredItems = [];
  double _currentZoom = 15.0;
  LatLng? _myLocation; 

  @override
  void initState() {
    super.initState();
    _fetchItems();
    _goToMyLocation();
  }

  Future<void> _fetchItems() async {
    try {
      final data = await Supabase.instance.client.from('items').select();
      if (mounted) {
        setState(() {
          _items = (data as List).map((e) => Item.fromMap(e)).toList();
          _filteredItems = _items;
        });
      }
    } catch (e) {
      debugPrint("Error fetching items: $e");
    }
  }

  void _filterItems(String query) {
    setState(() {
      _filteredItems = _items.where((i) => 
        i.title.toLowerCase().contains(query.toLowerCase()) || 
        i.locationName.toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }

  // --- SEARCH MAP LOGIC ---
  Future<void> _searchPlace(String query) async {
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus(); // Hide keyboard
    
    // 1. Filter Pins
    _filterItems(query);

    // 2. Search Map
    try {
      String fullQuery = "$query, UPM Serdang, Malaysia"; 
      List<Location> locations = await locationFromAddress(fullQuery);
      
      if (locations.isEmpty) {
        locations = await locationFromAddress(query); // Retry broader search
      }

      if (locations.isNotEmpty) {
        final loc = locations.first;
        _mapController.move(LatLng(loc.latitude, loc.longitude), 17.0);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Moved to $query")));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Place not found on map")));
      }
    } catch (e) {
      debugPrint("Place not found: $e");
    }
  }

  void _zoom(double change) {
    _currentZoom = (_currentZoom + change).clamp(10.0, 18.0);
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  Future<void> _goToMyLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      
      Position pos = await Geolocator.getCurrentPosition();
      
      setState(() {
        _myLocation = LatLng(pos.latitude, pos.longitude);
      });

      _mapController.move(_myLocation!, 16.0);
      
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(2.9926, 101.7079), 
              initialZoom: _currentZoom,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.upm.lostfound',
              ),
              MarkerLayer(
                markers: [
                  ..._filteredItems.where((i) => i.locationLat != null).map((item) {
                    return Marker(
                      point: LatLng(item.locationLat!, item.locationLng!),
                      width: 45, height: 45,
                      child: GestureDetector(
                        onTap: () => _showPreview(item),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5)),
                              child: Text(item.title, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                            ),
                            Icon(Icons.location_pin, color: item.type == 'lost' ? Colors.red : Colors.blue, size: 30),
                          ],
                        ),
                      ),
                    );
                  }).toList(),

                  // BLUE DOT (My Location)
                  if (_myLocation != null)
                    Marker(
                      point: _myLocation!,
                      width: 25, height: 25,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.8),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          
          Positioned(
            top: 50, left: 15, right: 15,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search, 
                decoration: InputDecoration(
                  hintText: "Search item or place...",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.clear), 
                        onPressed: () {
                          _searchController.clear();
                          _filterItems("");
                        }
                      ) 
                    : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(15),
                ),
                onChanged: _filterItems,
                onSubmitted: _searchPlace, 
              ),
            ),
          ),

          Positioned(
            bottom: 100, right: 15,
            child: Column(
              children: [
                FloatingActionButton.small(heroTag: "z+", onPressed: () => _zoom(1), backgroundColor: Colors.white, child: const Icon(Icons.add, color: Colors.black)),
                const SizedBox(height: 10),
                FloatingActionButton.small(heroTag: "z-", onPressed: () => _zoom(-1), backgroundColor: Colors.white, child: const Icon(Icons.remove, color: Colors.black)),
                const SizedBox(height: 10),
                FloatingActionButton(heroTag: "loc", onPressed: _goToMyLocation, backgroundColor: Colors.blue, child: const Icon(Icons.my_location, color: Colors.white)),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        height: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.type == 'lost' ? Colors.red.shade100 : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: Text(item.type.toUpperCase(), style: TextStyle(color: item.type == 'lost' ? Colors.red : Colors.blue, fontWeight: FontWeight.bold, fontSize: 10)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(item.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 10),
            Row(children: [const Icon(Icons.location_on, color: Colors.grey, size: 16), const SizedBox(width: 5), Expanded(child: Text(item.locationName))]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item))),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                child: const Text("View Details"),
              ),
            )
          ],
        ),
      )
    );
  }
}