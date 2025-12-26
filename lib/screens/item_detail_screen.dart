import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/item_model.dart';
import 'chat_screen.dart';
import 'route_map_screen.dart'; // <--- THIS WAS MISSING!

class ItemDetailScreen extends StatelessWidget {
  final Item item;
  const ItemDetailScreen({super.key, required this.item});

  // --- STAGE 1: Finder marks item as "At Faculty" ---
  Future<void> _markAsReturnedToFaculty(BuildContext context) async {
    String newDesc = "[AT FACULTY: ${item.dropOffNode}] \n\n${item.description}";
    
    await Supabase.instance.client.from('items').update({
      'description': newDesc,
    }).eq('id', item.id);
    
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Status Updated: Item is now at the faculty!")));
    }
  }

  // --- STAGE 2: Item Collected (Delete) ---
  Future<void> _markAsCollected(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Case Solved?"),
        content: const Text("Has this item been successfully collected? This will remove the post."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Yes, Collected")),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('messages').delete().eq('item_id', item.id);
        await Supabase.instance.client.from('items').delete().eq('id', item.id);
        
        if (context.mounted) {
          Navigator.pop(context); 
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Case Resolved! 🎉")));
        }
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

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
        bool isMultipleChoice = item.verificationOptions.isNotEmpty;

        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text("Security Check"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.verificationQuestion!, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                if (isMultipleChoice)
                  ...item.verificationOptions.map((option) => RadioListTile(
                    title: Text(option),
                    value: option,
                    groupValue: selectedAnswer,
                    onChanged: (val) => setState(() => selectedAnswer = val as String),
                  ))
                else 
                  TextField(controller: textController, decoration: const InputDecoration(labelText: "Answer"))
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  attempts++;
                  String finalAnswer = isMultipleChoice ? (selectedAnswer ?? "") : textController.text.trim();
                  if (finalAnswer.toLowerCase() == item.verificationAnswer?.toLowerCase()) {
                    Navigator.pop(ctx);
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

    if (verifiedFirstTry) {
       try { await Supabase.instance.client.from('messages').insert({'sender_id': myId, 'receiver_id': item.reportedBy, 'item_id': item.id, 'content': "[NOTICE]: Verified Owner! 🛡️"}); } catch (_) {}
    }

    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
        otherUserId: item.reportedBy!, 
        otherUserName: item.reportedUsername ?? "User",
        itemId: item.id,
        itemName: item.title,
      )));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final isFinder = myId == item.reportedBy;
    final isAtFaculty = item.description.contains("[AT FACULTY");

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 350,
                flexibleSpace: FlexibleSpaceBar(
                  background: item.imageUrls.isNotEmpty
                      ? Image.network(item.imageUrls[0], fit: BoxFit.cover)
                      : Container(color: Colors.grey.shade200),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(item.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    if (item.dropOffNode != null) ...[
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: isAtFaculty ? Colors.green.shade50 : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isAtFaculty ? Colors.green : Colors.orange),
                        ),
                        child: Column(
                          children: [
                            Text(isAtFaculty ? "Ready for Collection at:" : "Return to:", style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(item.dropOffNode!, style: const TextStyle(fontSize: 16)),
                            if (!isAtFaculty)
                              ElevatedButton.icon(
                                icon: const Icon(Icons.map, size: 16),
                                label: const Text("Show Route (Dijkstra)"),
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RouteMapScreen(destinationName: item.dropOffNode!))),
                              )
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Text(item.description, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 40),
                    if (isFinder) ...[
                      if (!isAtFaculty && item.dropOffNode != null)
                        ElevatedButton(onPressed: () => _markAsReturnedToFaculty(context), child: const Text("I Returned it to Faculty")),
                      if (isAtFaculty)
                        ElevatedButton(onPressed: () => _markAsCollected(context), child: const Text("Mark Collected")),
                    ] else ...[
                      if (!isAtFaculty) ElevatedButton(onPressed: () => _verifyAndClaim(context), child: const Text("Claim Item")),
                      const SizedBox(height: 10),
                      OutlinedButton(onPressed: () => _openChat(context, verifiedFirstTry: false), child: const Text("Chat")),
                    ]
                  ]),
                ),
              ),
            ],
          ),
          // Back Button
          Positioned(top: 50, left: 20, child: GestureDetector(onTap: () => Navigator.pop(context), child: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.arrow_back, color: Colors.black)))),
        ],
      ),
    );
  }
}