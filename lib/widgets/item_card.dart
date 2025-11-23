import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/item_model.dart';
import '../screens/item_detail_screen.dart';

class ItemCard extends StatelessWidget {
  final Item item;

  const ItemCard({super.key, required this.item});

  Future<void> _openWhatsApp() async {
    if (item.contactNumber == null || item.contactNumber!.isEmpty) return;
    // Basic cleaning of phone number
    String phone = item.contactNumber!.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse("https://wa.me/$phone?text=Hello, I saw your post about ${item.title} on UPM Lost&Found.");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch WhatsApp';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 3,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            if (item.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(item.imageUrl, height: 180, width: double.infinity, fit: BoxFit.cover),
              ),
            
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Chip(
                        label: Text(item.type.toUpperCase()), 
                        backgroundColor: item.type == 'lost' ? Colors.red.shade100 : Colors.blue.shade100,
                        labelStyle: TextStyle(color: item.type == 'lost' ? Colors.red : Colors.blue, fontWeight: FontWeight.bold),
                      ),
                      if (item.contactNumber != null && item.contactNumber!.isNotEmpty)
                        IconButton(
                          onPressed: _openWhatsApp,
                          icon: const Icon(Icons.message, color: Colors.green),
                          tooltip: "Chat on WhatsApp",
                        )
                    ],
                  ),
                  Text(item.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.place, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(child: Text(item.locationName, style: const TextStyle(color: Colors.grey))),
                    ],
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