import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  Future<String> _getItemName(String? itemId) async {
    if (itemId == null) return "Unknown Item";
    final data = await Supabase.instance.client.from('items').select('title').eq('id', itemId).maybeSingle();
    return data != null ? data['title'] : "Unknown Item";
  }

  // --- DELETE SINGLE NOTIFICATION ---
  Future<void> _deleteNotification(String id) async {
    await Supabase.instance.client.from('messages').delete().eq('id', id);
  }

  // --- CLEAR ALL NOTIFICATIONS ---
  Future<void> _clearAllNotifications(BuildContext context, String myId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear All?"),
        content: const Text("Delete all notifications? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Clear All", style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirm == true) {
      await Supabase.instance.client.from('messages').delete().eq('receiver_id', myId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser!.id;
    final stream = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text("Inbox"),
        backgroundColor: const Color(0xFFB30000), // Solid Color (UPM Red)
        foregroundColor: Colors.white, // White Text
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: "Clear All",
            onPressed: () => _clearAllNotifications(context, myId),
          )
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final allMessages = snapshot.data!;
          final Map<String, Map<String, dynamic>> conversations = {};
          
          for (var msg in allMessages) {
            String otherId = msg['sender_id'] == myId ? msg['receiver_id'] : msg['sender_id'];
            String itemId = msg['item_id'] ?? 'general';
            String key = "${otherId}_$itemId";
            if (!conversations.containsKey(key)) conversations[key] = msg;
          }

          final uniqueChats = conversations.values.toList();

          if (uniqueChats.isEmpty) {
            return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [Icon(Icons.notifications_none, size: 60, color: Colors.grey), SizedBox(height: 10), Text("No notifications yet")],
            ));
          }

          return ListView.builder(
            itemCount: uniqueChats.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final msg = uniqueChats[index];
              final itemId = msg['item_id'];
              final otherId = msg['sender_id'] == myId ? msg['receiver_id'] : msg['sender_id'];

              return Dismissible(
                key: Key(msg['id'].toString()),
                background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                onDismissed: (dir) => _deleteNotification(msg['id']),
                child: FutureBuilder<String>(
                  future: _getItemName(itemId),
                  builder: (context, itemSnap) {
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.person, color: Colors.white)),
                        title: Text(itemSnap.data ?? "Loading Item...", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(msg['content'], maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                            otherUserId: otherId,
                            otherUserName: "User",
                            itemId: itemId,
                            itemName: itemSnap.data,
                          )));
                        },
                      ),
                    );
                  }
                ),
              );
            },
          );
        },
      ),
    );
  }
}