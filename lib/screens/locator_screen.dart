import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/item_model.dart';
import 'item_detail_screen.dart';

class LocatorScreen extends StatelessWidget {
  const LocatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // UPM Serdang Center
    final LatLng center = LatLng(2.9926, 101.7079); 

    final stream = Supabase.instance.client
        .from('items')
        .stream(primaryKey: ['id'])
        .order('created_at');

    return Scaffold(
      appBar: AppBar(title: const Text("Live Locator")),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          List<Marker> markers = [];
          
          if (snapshot.hasData) {
            final items = snapshot.data!.map((e) => Item.fromMap(e)).toList();
            
            markers = items
                .where((item) => item.locationLat != null && item.locationLng != null)
                .map((item) {
              return Marker(
                point: LatLng(item.locationLat!, item.locationLng!),
                width: 45,
                height: 45,
                child: GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (_) => _ItemPreviewSheet(item: item),
                    );
                  },
                  child: Icon(
                    Icons.location_pin,
                    color: item.type == 'lost' ? Colors.red : Colors.blue,
                    size: 45,
                    shadows: const [Shadow(blurRadius: 10, color: Colors.black45)],
                  ),
                ),
              );
            }).toList();
          }

          return FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15.5,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.example.upm_lost_found',
              ),
              MarkerLayer(markers: markers),
            ],
          );
        },
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
      height: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(item.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.type == 'lost' ? Colors.red.shade100 : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(item.type.toUpperCase(), 
                  style: TextStyle(color: item.type == 'lost' ? Colors.red : Colors.blue, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)));
              },
              child: const Text("View Details"),
            ),
          )
        ],
      ),
    );
  }
}