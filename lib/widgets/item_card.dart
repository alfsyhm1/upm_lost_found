import 'package:flutter/material.dart';
import '../models/item_model.dart';
import '../screens/item_detail_screen.dart';

class ItemCard extends StatelessWidget {
  final Item item;
  const ItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(10),
      child: ListTile(
        leading: item.imageUrl.isNotEmpty
            ? Image.network(item.imageUrl, width: 60, fit: BoxFit.cover)
            : const Icon(Icons.image_not_supported),
        title: Text(item.title),
        subtitle: Text(item.description),
        onTap: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)));
        },
      ),
    );
  }
}
