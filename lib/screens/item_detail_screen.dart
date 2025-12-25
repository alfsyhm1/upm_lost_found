import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/item_model.dart';
import 'chat_screen.dart';

class ItemDetailScreen extends StatelessWidget {
  final Item item;
  const ItemDetailScreen({super.key, required this.item});

  Future<void> _makeCall() async {
    if (item.contactNumber == null) return;
    final url = Uri.parse("tel:${item.contactNumber}");
    if (!await launchUrl(url)) throw 'Could not launch $url';
  }

  Future<void> _openWhatsApp() async {
    if (item.contactNumber == null) return;
    String phone = item.contactNumber!.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse("https://wa.me/$phone?text=Regarding your post: ${item.title}");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) throw 'Could not launch WhatsApp';
  }

  void _verifyAndClaim(BuildContext context) {
    if (item.verificationQuestion == null) {
      // No security question, go straight to chat
      _openChat(context);
      return;
    }

    final answerController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Security Question"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("The finder set this question to verify ownership:", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 10),
            Text(item.verificationQuestion!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 15),
            TextField(controller: answerController, decoration: const InputDecoration(labelText: "Your Answer", border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (answerController.text.trim().toLowerCase() == item.verificationAnswer?.toLowerCase()) {
                Navigator.pop(ctx);
                _openChat(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Incorrect answer"), backgroundColor: Colors.red));
              }
            },
            child: const Text("Verify"),
          ),
        ],
      ),
    );
  }

  void _openChat(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser?.id == item.reportedBy) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You posted this item!")));
      return;
    }
    
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
      otherUserId: item.reportedBy!, 
      otherUserName: item.reportedUsername ?? "User",
      itemId: item.id,
    )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: item.imageUrls.isNotEmpty
                  ? PageView.builder(
                      itemCount: item.imageUrls.length,
                      itemBuilder: (ctx, i) => Image.network(item.imageUrls[i], fit: BoxFit.cover),
                    )
                  : Container(color: Colors.grey.shade200, child: const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey))),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: item.type == 'lost' ? Colors.red.shade50 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: item.type == 'lost' ? Colors.red.shade200 : Colors.blue.shade200),
                      ),
                      child: Text(item.type.toUpperCase(), style: TextStyle(color: item.type == 'lost' ? Colors.red : Colors.blue, fontWeight: FontWeight.bold)),
                    ),
                    const Spacer(),
                    Text(item.createdAt.toString().split(' ')[0], style: const TextStyle(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 15),
                Text(item.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.grey, size: 20),
                    const SizedBox(width: 5),
                    Expanded(child: Text(item.locationName, style: const TextStyle(color: Colors.grey, fontSize: 16))),
                  ],
                ),
                const SizedBox(height: 20),
                const Text("Description", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(item.description, style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87)),
                const SizedBox(height: 30),
                
                // ACTION BUTTONS
                if (item.reportedBy != Supabase.instance.client.auth.currentUser?.id) ...[
                  if (item.type == 'found')
                    ElevatedButton.icon(
                      onPressed: () => _verifyAndClaim(context),
                      icon: const Icon(Icons.verified_user),
                      label: const Text("Claim this Item"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openChat(context),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text("Chat"),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (item.contactNumber != null && item.contactNumber!.isNotEmpty)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openWhatsApp,
                            icon: const Icon(Icons.message),
                            label: const Text("WhatsApp"),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white, minimumSize: const Size(0, 50)),
                          ),
                        ),
                    ],
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}