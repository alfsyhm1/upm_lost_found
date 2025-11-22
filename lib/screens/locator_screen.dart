import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/item_model.dart';
//import '../services/item_detail_screen.dart';

class LocatorScreen extends StatefulWidget {
  const LocatorScreen({super.key});

  @override
  State<LocatorScreen> createState() => _LocatorScreenState();
}

class _LocatorScreenState extends State<LocatorScreen> {
  List<Item> items = [];
  
  // UPM Serdang approximate center
  final LatLng _center = LatLng(2.9926, 101.7079); 

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    final response = await Supabase.instance.client
        .from('items')
        .select()
        .not('location_lat', 'is', null); // Only get items with location
    
    if (mounted) {
      setState(() {
        items = (response as List).map((e) => Item.fromMap(e)).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Live Item Locator")),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: _center,
          initialZoom: 15.0,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            userAgentPackageName: 'com.example.upm_lost_found',
          ),
          MarkerLayer(
            markers: items.map((item) {
              return Marker(
                point: LatLng(item.locationLat!, item.locationLng!), // Ensure model has double? lat/lng
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context, 
                      builder: (_) => _ItemPreviewSheet(item: item)
                    );
                  },
                  child: Icon(
                    Icons.location_on, 
                    color: item.type == 'lost' ? Colors.red : Colors.blue,
                    size: 40,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ItemPreviewSheet extends StatelessWidget {
  final Item item;
  const _ItemPreviewSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(item.type.toUpperCase(), style: TextStyle(color: item.type == 'lost' ? Colors.red : Colors.blue)),
          const SizedBox(height: 10),
          Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)));
              }, 
              child: const Text("View Details")
            ),
          )
        ],
      ),
    );
  }
}