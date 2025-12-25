import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:confetti/confetti.dart';
import '../models/item_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = Supabase.instance.client.auth.currentUser;
  late ConfettiController _confettiController;
  String _username = "Loading...";

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _fetchProfile();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('username')
          .eq('id', user!.id)
          .maybeSingle();
      if (data != null && data['username'] != null) {
        setState(() => _username = data['username']);
      } else {
        setState(() => _username = "Set Username");
      }
    } catch (e) {
      setState(() => _username = "User");
    }
  }

  // --- NEW: Update Username Feature ---
  Future<void> _updateUsername() async {
    String? newName;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Set Username"),
        content: TextField(
          onChanged: (v) => newName = v,
          decoration: const InputDecoration(hintText: "e.g. Ali UPM"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              if (newName != null && newName!.isNotEmpty) {
                await Supabase.instance.client.from('profiles').upsert({
                  'id': user!.id,
                  'username': newName,
                });
                setState(() => _username = newName!);
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsReturned(String itemId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Mark as Resolved?"),
        content: const Text("Is this item back with its owner? This will remove it from the list."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Yes, Resolved!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm == true) {
      _confettiController.play();
      await Supabase.instance.client.from('items').delete().eq('id', itemId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Great job! Item resolved! 🎉"), backgroundColor: Colors.green)
        );
      }
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final myItemsStream = Supabase.instance.client
        .from('items')
        .stream(primaryKey: ['id'])
        .eq('reported_by', user?.id ?? '')
        .order('created_at', ascending: false);

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Scaffold(
          appBar: AppBar(title: const Text("My Profile")),
          body: Column(
            children: [
              // Profile Header
              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.red.shade50,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 35, 
                      backgroundColor: const Color(0xFFB30000), 
                      child: Text(user?.email?.substring(0,1).toUpperCase() ?? "U", style: const TextStyle(fontSize: 30, color: Colors.white))
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Username with Edit capability
                          GestureDetector(
                            onTap: _updateUsername,
                            child: Row(
                              children: [
                                Text(_username, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                const Icon(Icons.edit, size: 16, color: Colors.grey),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(user?.email ?? "", style: const TextStyle(fontSize: 14, color: Colors.grey)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: _logout, icon: const Icon(Icons.logout), color: Colors.red),
                  ],
                ),
              ),
              
              const Padding(
                padding: EdgeInsets.all(15.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("My Reports", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              ),
              
              // List
              Expanded(
                child: StreamBuilder(
                  stream: myItemsStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final data = snapshot.data as List<dynamic>;
                    final items = data.map((e) => Item.fromMap(e)).toList();

                    if (items.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 60, color: Colors.grey.shade300),
                            const SizedBox(height: 10),
                            const Text("No reports yet."),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: item.imageUrls.isNotEmpty
                                 ? Image.network(item.imageUrls.first, width: 50, height: 50, fit: BoxFit.cover)
                                 : Container(color: Colors.grey.shade200, width: 50, height: 50, child: const Icon(Icons.image)),
                            ),
                            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(item.type.toUpperCase(), style: TextStyle(color: item.type == 'lost' ? Colors.red : Colors.blue, fontSize: 12)),
                            trailing: ElevatedButton.icon(
                              onPressed: () => _markAsReturned(item.id),
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text("Resolved"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade50,
                                foregroundColor: Colors.green.shade700,
                                elevation: 0,
                              ),
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
        ),
        
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange],
          numberOfParticles: 20,
          gravity: 0.3,
        ),
      ],
    );
  }
}