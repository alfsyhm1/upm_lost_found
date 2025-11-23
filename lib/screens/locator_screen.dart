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

    // Fetch ALL items to show on map
    final stream = Supabase.instance.client
        .from('items')
        .stream(primaryKey: ['id']);

    return Scaffold(
      appBar: AppBar(title: const Text("Live Map Locator")),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          List<Marker> markers = [];
          
          if (snapshot.hasData && snapshot.data != null) {
            final items = snapshot.data!.map((e) => Item.fromMap(e)).toList();
            
            // Debug print to console
            print("Found ${items.length} items. Filtering for location...");

            markers = items
                .where((item) => item.locationLat != null && item.locationLng != null)
                .map((item) {
                  return Marker(
                    point: LatLng(item.locationLat!, item.locationLng!),
                    width: 50, // Made bigger
                    height: 50,
                    child: GestureDetector(
                      onTap: () {
                        // Show bottom sheet on tap
                        showModalBottomSheet(
                          context: context,
                          builder: (_) => _ItemPreviewSheet(item: item),
                        );
                      },
                      child: Icon(
                        Icons.location_on, // Standard pin icon
                        color: item.type == 'lost' ? Colors.red : Colors.blue,
                        size: 50,
                        shadows: const [Shadow(blurRadius: 5, color: Colors.black54)],
                      ),
                    ),
                  );
            }).toList();
          }

          return FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.example.upm_lost_found',
              ),
              MarkerLayer(markers: markers), // Pins are added here
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
      padding: const EdgeInsets.all(20),
      height: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(item.type.toUpperCase(), 
             style: TextStyle(
               color: item.type == 'lost' ? Colors.red : Colors.blue, 
               fontWeight: FontWeight.bold
             )
           ),
           const SizedBox(height: 5),
           Text(item.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
           const SizedBox(height: 10),
           Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis),
           const Spacer(),
           SizedBox(
             width: double.infinity,
             child: ElevatedButton(
               onPressed: () {
                 Navigator.pop(context); // Close sheet
                 Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)));
               },
               child: const Text("View Full Details & Route"),
             ),
           )
        ],
      ),
    );
  }
}