import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

class ChatScreen extends StatefulWidget {
  final String otherUserId; // ID of the other user in the chat
  final String otherUserName; // Name of the other user
  final String? itemId; // ID of the item being discussed
  final String? itemName; // <--- Added this to fix the error, title of the item being discussed

  const ChatScreen({  
    super.key,  
    required this.otherUserId, 
    required this.otherUserName, 
    this.itemId,
    this.itemName, // <--- Added this to constructor
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();  // Create state for ChatScreen
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController(); // Controller for message input
  final _myId = Supabase.instance.client.auth.currentUser!.id;  // Current user's ID
  late Stream<List<Map<String, dynamic>>> _messagesStream;  // Stream for messages

  @override
  void initState() {
    super.initState();  // Initialize the messages stream
    _messagesStream = Supabase.instance.client  // Initialize the messages stream
        .from('messages') // Messages table
        .stream(primaryKey: ['id']) // Primary key
        .order('created_at', ascending: false) // Newest messages at the bottom
        .map((data) => data.where((msg) => // Filter messages between the two users
            (msg['sender_id'] == _myId && msg['receiver_id'] == widget.otherUserId) ||  // messages sent by me
            (msg['sender_id'] == widget.otherUserId && msg['receiver_id'] == _myId) // messages received by me
        ).toList());
  }

  Future<void> _sendMessage() async { // Send message function
    final text = _messageController.text.trim();  // Get and trim message text
    if (text.isEmpty) return; // Do nothing if message is empty
    _messageController.clear(); // Clear the input field

    // Insert the new message into the database
    await Supabase.instance.client.from('messages').insert({  // Insert into messages table
      'sender_id': _myId,
      'receiver_id': widget.otherUserId,
      'item_id': widget.itemId,
      'content': text,
    });
  }

  @override
  Widget build(BuildContext context) {  // Build the chat screen UI
    return Scaffold(
      appBar: AppBar(title: Text(widget.otherUserName)),
      body: Column(
        children: [
          // --- STICKY ITEM HEADER ---
          if (widget.itemName != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border(bottom: BorderSide(color: Colors.blue.shade100)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Chatting about: ${widget.itemName}",
                      style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          // --------------------------

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final messages = snapshot.data!;
                
                return ListView.builder(
                  reverse: true, 
                  padding: const EdgeInsets.all(10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'] == _myId;
                    String content = msg['content'];

                    // --- SYSTEM NOTICE RENDERER ---
                    if (content.startsWith("[NOTICE]:")) {
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 15),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade300)
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.verified_user, color: Colors.green),
                              const SizedBox(height: 5),
                              Text(
                                content.replaceAll("[NOTICE]:", "").trim(),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    // -----------------------------

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(content, style: TextStyle(color: isMe ? Colors.white : Colors.black)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _messageController, decoration: InputDecoration(hintText: "Type a message...", filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)))),
                IconButton(onPressed: _sendMessage, icon: const Icon(Icons.send, color: Colors.blue)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}