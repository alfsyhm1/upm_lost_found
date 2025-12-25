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
  String _emoji = "👤"; // Default

  final List<String> _emojis = ["👤", "🐱", "🐶", "🦊", "🦁", "🐸", "🦄", "🤖", "👽", "👻"];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final data = await Supabase.instance.client.from('profiles').select().eq('id', user!.id).maybeSingle();
      if (data != null) {
        setState(() {
          _username = data['username'] ?? "Set Username";
          _emoji = data['avatar_emoji'] ?? "👤";
        });
      }
    } catch (_) {}
  }

  Future<void> _updateEmoji() async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => GridView.count(
        crossAxisCount: 5,
        children: _emojis.map((e) => GestureDetector(
          onTap: () async {
            setState(() => _emoji = e);
            Navigator.pop(ctx);
            await Supabase.instance.client.from('profiles').upsert({'id': user!.id, 'avatar_emoji': e});
          },
          child: Center(child: Text(e, style: const TextStyle(fontSize: 30))),
        )).toList(),
      ),
    );
  }

  Future<void> _markAsReturned(Item item) async {
    // Logic: If 'lost', status becomes 'Found'. If 'found', status becomes 'Returned'.
    String statusText = item.type == 'lost' ? "FOUND" : "RETURNED";
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Mark as $statusText?"),
        content: const Text("This will resolve the item and remove it from the list."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Confirm")),
        ],
      ),
    );

    if (confirm == true) {
      _confettiController.play();
      await Supabase.instance.client.from('items').delete().eq('id', item.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Item marked as $statusText! 🎉")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myItemsStream = Supabase.instance.client.from('items').stream(primaryKey: ['id']).eq('reported_by', user?.id ?? '').order('created_at');

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Scaffold(
          appBar: AppBar(title: const Text("My Profile")),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.grey.shade100,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _updateEmoji,
                      child: CircleAvatar(radius: 35, backgroundColor: Colors.white, child: Text(_emoji, style: const TextStyle(fontSize: 35))),
                    ),
                    const SizedBox(width: 15),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_username, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(user?.email ?? "", style: const TextStyle(color: Colors.grey)),
                    ])),
                    IconButton(onPressed: () => Supabase.instance.client.auth.signOut().then((_) => Navigator.pushReplacementNamed(context, '/login')), icon: const Icon(Icons.logout, color: Colors.red)),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder(
                  stream: myItemsStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final items = (snapshot.data as List).map((e) => Item.fromMap(e)).toList();
                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (ctx, i) {
                        final item = items[i];
                        return ListTile(
                          title: Text(item.title),
                          subtitle: Text(item.type.toUpperCase()),
                          trailing: ElevatedButton(
                            onPressed: () => _markAsReturned(item),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade100, foregroundColor: Colors.green.shade800, elevation: 0),
                            child: Text(item.type == 'lost' ? "Mark Found" : "Mark Returned"),
                          ),
                        );
                      },
                    );
                  },
                ),
              )
            ],
          ),
        ),
        ConfettiWidget(confettiController: _confettiController, blastDirectionality: BlastDirectionality.explosive, numberOfParticles: 20),
      ],
    );
  }
}