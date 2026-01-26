import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser!.id; // acquiring the id of the user

    // Fetch conversations (unique senders) -- live conversations
    final stream = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(title: const Text("Notifications"), backgroundColor: Colors.transparent, elevation: 0),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: Text("No new alerts"));
          
          // Filter messages where I am the receiver
          final myMessages = snapshot.data!.where((m) => m['receiver_id'] == myId).toList();
          
          if (myMessages.isEmpty) {
            return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [Icon(Icons.notifications_none, size: 60, color: Colors.grey), SizedBox(height: 10), Text("No notifications yet")],
            ));
          }

          return ListView.builder(
            itemCount: myMessages.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final msg = myMessages[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.chat, color: Colors.white)),
                  title: const Text("New Message"),
                  subtitle: Text(msg['content']),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    // Navigate to chat
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                      otherUserId: msg['sender_id'], 
                      otherUserName: "User", // Ideally fetch name
                    )));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}