import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/item_model.dart';
import '../screens/item_detail_screen.dart';

class ItemCard extends StatelessWidget {
  final Item item;

  const ItemCard({super.key, required this.item});

  Future<void> _openWhatsApp() async {
    if (item.contactNumber == null || item.contactNumber!.isEmpty) return;
    String phone = item.contactNumber!.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse("https://wa.me/$phone?text=Regarding your post: ${item.title}");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch WhatsApp';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), // Compact margin
      elevation: 2,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item))),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            children: [
              // 1. Small Thumbnail Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.imageUrl.isNotEmpty
                    ? Image.network(item.imageUrl, width: 80, height: 80, fit: BoxFit.cover)
                    : Container(width: 80, height: 80, color: Colors.grey.shade200, child: const Icon(Icons.image)),
              ),
              const SizedBox(width: 15),
              
              // 2. Info Section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title, 
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.locationName.isNotEmpty ? item.locationName : "No location",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.type == 'lost' ? Colors.red.shade50 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: item.type == 'lost' ? Colors.red.shade200 : Colors.blue.shade200),
                      ),
                      child: Text(
                        item.type.toUpperCase(), 
                        style: TextStyle(fontSize: 10, color: item.type == 'lost' ? Colors.red : Colors.blue, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. WhatsApp Button (if valid)
              if (item.contactNumber != null && item.contactNumber!.length > 5)
                IconButton(
                  onPressed: _openWhatsApp,
                  icon: const Icon(Icons.message, color: Colors.green),
                  tooltip: "Chat",
                ),
            ],
          ),
        ),
      ),
    );
  }
}