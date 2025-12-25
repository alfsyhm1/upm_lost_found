import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/item_model.dart';
import 'chat_screen.dart';

class ItemDetailScreen extends StatelessWidget {
  final Item item;
  const ItemDetailScreen({super.key, required this.item});

  void _verifyAndClaim(BuildContext context) {
    if (item.verificationQuestion == null) {
      _openChat(context, verifiedFirstTry: false);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        String? selectedAnswer;
        final textController = TextEditingController();
        int attempts = 0; 

        // Check if we have options (Multiple Choice) or not (Text Input)
        bool isMultipleChoice = item.verificationOptions.isNotEmpty;

        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text("Security Check"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.verificationQuestion!, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                
                // Render Radio Buttons OR Text Field
                if (isMultipleChoice)
                  ...item.verificationOptions.map((option) => RadioListTile(
                    title: Text(option),
                    value: option,
                    groupValue: selectedAnswer,
                    onChanged: (val) => setState(() => selectedAnswer = val as String),
                  ))
                else 
                  TextField(
                    controller: textController,
                    decoration: const InputDecoration(labelText: "Type your answer", border: OutlineInputBorder()),
                  )
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  attempts++;
                  // Get answer based on mode
                  String finalAnswer = isMultipleChoice ? (selectedAnswer ?? "") : textController.text.trim();
                  
                  // Compare (Case insensitive)
                  if (finalAnswer.toLowerCase() == item.verificationAnswer?.toLowerCase()) {
                    Navigator.pop(ctx);
                    // Pass true if verified on first try
                    _openChat(context, verifiedFirstTry: attempts == 1);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Incorrect!"), backgroundColor: Colors.red));
                  }
                },
                child: const Text("Verify"),
              )
            ],
          );
        });
      },
    );
  }

  void _openChat(BuildContext context, {required bool verifiedFirstTry}) async {
    final myId = Supabase.instance.client.auth.currentUser!.id;
    if (myId == item.reportedBy) return;

    String contextMessage = "👋 Hi, I am interested in the '${item.title}' you posted.";
    
    // --- SEND SYSTEM NOTICE ---
    if (verifiedFirstTry) {
      String specialNotice = "[NOTICE]: Verified Owner! 🛡️\nI answered the security question correctly on the first try.";
      try {
        await Supabase.instance.client.from('messages').insert({
          'sender_id': myId, 'receiver_id': item.reportedBy, 'item_id': item.id, 'content': specialNotice,
        });
      } catch (_) {}
    }
    // --------------------------

    try {
      await Supabase.instance.client.from('messages').insert({
        'sender_id': myId, 'receiver_id': item.reportedBy, 'item_id': item.id, 'content': contextMessage,
      });
    } catch (_) {}

    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
        otherUserId: item.reportedBy!, otherUserName: item.reportedUsername ?? "User", itemId: item.id,
      )));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 350,
                pinned: true,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: item.imageUrls.isNotEmpty
                      ? PageView.builder(itemCount: item.imageUrls.length, itemBuilder: (ctx, i) => Image.network(item.imageUrls[i], fit: BoxFit.cover))
                      : Container(color: Colors.grey.shade200, child: const Icon(Icons.image, size: 60)),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(item.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.pin_drop, color: Colors.grey),
                        const SizedBox(width: 5),
                        Text(item.locationName, style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const Divider(height: 30),
                    Text(item.description, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 40),
                    
                    if (Supabase.instance.client.auth.currentUser?.id != item.reportedBy) ...[
                      if (item.type == 'found')
                        SizedBox(
                          width: double.infinity, height: 50,
                          child: ElevatedButton(
                            onPressed: () => _verifyAndClaim(context), 
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text("Claim Item", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () => _openChat(context, verifiedFirstTry: false),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text("Chat with Finder"),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.black), foregroundColor: Colors.black),
                        ),
                      )
                    ]
                  ]),
                ),
              ),
            ],
          ),
          Positioned(
            top: 50, left: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)]),
                child: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}