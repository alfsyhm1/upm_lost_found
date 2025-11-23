import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Import this
import '../models/item_model.dart';

class ItemDetailScreen extends StatelessWidget {
  final Item item;

  const ItemDetailScreen({super.key, required this.item});

  // Function to open Google Maps
  Future<void> _openMap() async {
    if (item.locationLat == null || item.locationLng == null) return;

    final Uri googleMapsUrl = Uri.parse(
        "https://www.google.com/maps/search/?api=1&query=${item.locationLat},${item.locationLng}");

    if (!await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch map');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Item Details")),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image
            if (item.imageUrl.isNotEmpty)
              Image.network(item.imageUrl, height: 300, fit: BoxFit.cover)
            else
              Container(
                height: 200, 
                color: Colors.grey.shade300, 
                child: const Icon(Icons.image_not_supported, size: 50)
              ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  
                  // Tags
                  Row(
                    children: [
                       Chip(
                         label: Text(item.type.toUpperCase()), 
                         backgroundColor: item.type == 'lost' ? Colors.red.shade100 : Colors.blue.shade100
                       ),
                       const SizedBox(width: 10),
                       Chip(label: Text(item.category)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const Text("Description", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(item.description, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 20),

                  const Text("Location", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(item.locationName.isNotEmpty ? item.locationName : "No location name provided"),
                  
                  const SizedBox(height: 30),

                  // Open Google Maps Button
                  if (item.locationLat != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openMap,
                        icon: const Icon(Icons.map),
                        label: const Text("Navigate with Google Maps"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}