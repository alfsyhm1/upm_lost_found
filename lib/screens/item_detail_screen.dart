import 'package:flutter/material.dart';
import '../models/item_model.dart';
import 'route_map_screen.dart';

class ItemDetailScreen extends StatelessWidget {
  final Item item;
  const ItemDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(item.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (item.imageUrl.isNotEmpty)
              Image.network(item.imageUrl, height: 200, fit: BoxFit.cover),
            const SizedBox(height: 20),
            Text(item.description),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text('View Route to Faculty'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RouteMap(startId: 'FSKTM', endId: 'Library'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
