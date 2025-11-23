import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/item_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = Supabase.instance.client.auth.currentUser;

  // Delete item function
  Future<void> _deleteItem(String itemId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Item?"),
        content: const Text("This will permanently remove the item from the list. Use this if the item has been returned."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.from('items').delete().eq('id', itemId);
      setState(() {}); // Refresh list
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Item removed.")));
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    // Stream of "My Items"
    final myItemsStream = Supabase.instance.client
        .from('items')
        .stream(primaryKey: ['id'])
        .eq('reported_by', user?.id ?? '')
        .order('created_at', ascending: false);

    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: Column(
        children: [
          // Profile Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const CircleAvatar(radius: 30, backgroundColor: Colors.red, child: Icon(Icons.person, color: Colors.white)),
                const SizedBox(width: 15),
                Expanded(child: Text(user?.email ?? "User", style: const TextStyle(fontSize: 18))),
                IconButton(onPressed: _logout, icon: const Icon(Icons.logout), color: Colors.red),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("Manage My Posts", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          
          // List of My Items
          Expanded(
            child: StreamBuilder(
              stream: myItemsStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final data = snapshot.data as List<dynamic>;
                final items = data.map((e) => Item.fromMap(e)).toList();

                if (items.isEmpty) return const Center(child: Text("You haven't posted anything yet."));

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: item.imageUrl.isNotEmpty 
                           ? Image.network(item.imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                           : const Icon(Icons.image),
                        title: Text(item.title),
                        subtitle: Text(item.type.toUpperCase(), style: TextStyle(color: item.type == 'lost' ? Colors.red : Colors.blue)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteItem(item.id),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}