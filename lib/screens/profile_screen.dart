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
  String _emoji = "👤"; 

  // UPM Red Theme Color
  final Color _brandRed = const Color(0xFFB30000);

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

  // --- 1. CHANGE EMOJI ---
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

  // --- 2. CHANGE USERNAME ---
  Future<void> _changeUsername() async {
    final controller = TextEditingController(text: _username);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Update Username"),
        content: TextField(
          controller: controller, 
          decoration: const InputDecoration(labelText: "New Username", border: OutlineInputBorder())
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await Supabase.instance.client.from('profiles').upsert({'id': user!.id, 'username': newName});
                setState(() => _username = newName);
                if (mounted) Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _brandRed, foregroundColor: Colors.white),
            child: const Text("Save"),
          )
        ],
      )
    );
  }

  // --- 3. CHANGE PASSWORD ---
  Future<void> _changePassword() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Change Password"),
        content: TextField(
          controller: controller, 
          obscureText: true, 
          decoration: const InputDecoration(labelText: "New Password", border: OutlineInputBorder())
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final newPass = controller.text.trim();
              if (newPass.length >= 6) {
                try {
                  await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPass));
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password updated successfully!")));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password must be at least 6 characters")));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _brandRed, foregroundColor: Colors.white),
            child: const Text("Update"),
          )
        ],
      )
    );
  }

  Future<void> _markAsReturned(Item item) async {
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
      try {
        await Supabase.instance.client.from('messages').delete().eq('item_id', item.id);
      } catch (_) {} 
      
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
          backgroundColor: const Color(0xFFF5F5F7),
          appBar: AppBar(
            title: const Text("My Profile", style: TextStyle(color: Colors.white)),
            backgroundColor: _brandRed,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Column(
            children: [
              // HEADER SECTION
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white, 
                  border: Border(bottom: BorderSide(color: Colors.black12))
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _updateEmoji,
                          child: CircleAvatar(
                            radius: 35, 
                            backgroundColor: Colors.grey.shade200, 
                            child: Text(_emoji, style: const TextStyle(fontSize: 35))
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(
                            children: [
                              Flexible(child: Text(_username, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 5),
                              // EDIT USERNAME ICON (RED)
                              IconButton(
                                onPressed: _changeUsername, 
                                icon: Icon(Icons.edit, size: 18, color: _brandRed),
                                tooltip: "Edit Username",
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          Text(user?.email ?? "", style: const TextStyle(color: Colors.grey)),
                        ])),
                        IconButton(onPressed: () => Supabase.instance.client.auth.signOut().then((_) => Navigator.pushReplacementNamed(context, '/login')), icon: const Icon(Icons.logout, color: Colors.red)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    
                    // CHANGE PASSWORD BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _changePassword, 
                        icon: Icon(Icons.lock_outline, size: 18, color: _brandRed),
                        label: Text("Change Password", style: TextStyle(color: _brandRed)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _brandRed.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              
              // MY ITEMS LIST
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Align(alignment: Alignment.centerLeft, child: Text("My Reported Items", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
              ),
              Expanded(
                child: StreamBuilder(
                  stream: myItemsStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final items = (snapshot.data as List).map((e) => Item.fromMap(e)).toList();
                    
                    if (items.isEmpty) return const Center(child: Text("You haven't reported any items."));

                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (ctx, i) {
                        final item = items[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(item.type.toUpperCase(), style: TextStyle(color: item.type == 'lost' ? Colors.red : Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                            trailing: ElevatedButton(
                              onPressed: () => _markAsReturned(item),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade50, 
                                foregroundColor: Colors.green.shade800, 
                                elevation: 0
                              ),
                              child: Text(item.type == 'lost' ? "Mark Found" : "Mark Returned"),
                            ),
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