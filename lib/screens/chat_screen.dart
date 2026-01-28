import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? itemId;
  final String? itemName;

  static String? activeChatUserId; 

  const ChatScreen({
    super.key, 
    required this.otherUserId, 
    required this.otherUserName, 
    this.itemId,
    this.itemName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _myId = Supabase.instance.client.auth.currentUser!.id;
  late Stream<List<Map<String, dynamic>>> _messagesStream;

  // UPM Red Color Constant
  final Color _brandRed = const Color(0xFFB30000);

  final List<String> _quickReplies = [
    "Is this item still with you?",
    "I can pick it up today.",
    "Where exactly did you find it?",
    "Thank you so much!",
    "I'd like to claim this item.",
    "On my way!"
  ];

  @override
  void initState() {
    super.initState();
    ChatScreen.activeChatUserId = widget.otherUserId;

    _messagesStream = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data.where((msg) => 
            (msg['sender_id'] == _myId && msg['receiver_id'] == widget.otherUserId) ||
            (msg['sender_id'] == widget.otherUserId && msg['receiver_id'] == _myId)
        ).toList());
  }

  @override
  void dispose() {
    ChatScreen.activeChatUserId = null;
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();

    await Supabase.instance.client.from('messages').insert({
      'sender_id': _myId,
      'receiver_id': widget.otherUserId,
      'item_id': widget.itemId,
      'content': text,
    });
  }

  Future<void> _deleteMessage(String msgId) async {
    await Supabase.instance.client.from('messages').delete().eq('id', msgId);
  }

  Future<void> _editMessage(String msgId, String oldContent) async {
    _messageController.text = oldContent;
    await _deleteMessage(msgId);
  }

  void _showOptions(String msgId, String content, bool isMe) {
    if (!isMe) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(15))),
      builder: (_) => Wrap(
        children: [
          ListTile(leading: const Icon(Icons.edit), title: const Text("Edit"), onTap: () { Navigator.pop(context); _editMessage(msgId, content); }),
          ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text("Delete"), onTap: () { Navigator.pop(context); _deleteMessage(msgId); }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName, style: const TextStyle(color: Colors.white)),
        backgroundColor: _brandRed, // Red App Bar
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          if (widget.itemName != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100, // Neutral background
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: _brandRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Chatting about: ${widget.itemName}", 
                      style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13), 
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis
                    ),
                  ),
                ],
              ),
            ),
          
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

                    if (content.startsWith("[NOTICE]:")) {
                      return _buildSystemMessage(content, Colors.green, Icons.verified_user);
                    }
                    if (content.startsWith("[ALERT]:")) {
                      return _buildSystemMessage(content, Colors.orange, Icons.warning_amber_rounded);
                    }

                    return GestureDetector(
                      onLongPress: () => _showOptions(msg['id'].toString(), content, isMe),
                      child: Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            // RED for Me, GREY for Others
                            color: isMe ? _brandRed : Colors.grey.shade200, 
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                              bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                            ),
                          ),
                          child: Text(content, style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Quick Replies
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _quickReplies.length,
              itemBuilder: (ctx, i) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ActionChip(
                  label: Text(_quickReplies[i], style: TextStyle(color: _brandRed, fontSize: 12)),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: _brandRed.withOpacity(0.2)),
                  onPressed: () => _messageController.text = _quickReplies[i],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController, 
                    decoration: InputDecoration(
                      hintText: "Type a message...", 
                      filled: true, 
                      fillColor: Colors.grey.shade100, 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    )
                  )
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _brandRed,
                  child: IconButton(
                    onPressed: _sendMessage, 
                    icon: const Icon(Icons.send, color: Colors.white, size: 20)
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(String text, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 15),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 5),
            Text(text.split(':').last.trim(), textAlign: TextAlign.center, style: TextStyle(color: color.withOpacity(0.9), fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}