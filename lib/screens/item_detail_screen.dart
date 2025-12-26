import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // REQUIRED PACKAGE
import '../models/item_model.dart';
import '../models/faculty_model.dart'; // To get coordinates
import 'chat_screen.dart';

class ItemDetailScreen extends StatelessWidget {
  final Item item;
  const ItemDetailScreen({super.key, required this.item});

  Future<void> _launchMaps() async {
    try {
      // Find the faculty node to get coordinates
      final node = facultyNodes.firstWhere((n) => n.name == item.dropOffNode);
      final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=${node.latitude},${node.longitude}");
      
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch maps';
      }
    } catch (e) {
      // Fallback if name doesn't match perfectly
      final fallbackUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(item.dropOffNode!)}");
      launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _markAsReturnedToFaculty(BuildContext context) async {
    final picController = TextEditingController();
    final locationController = TextEditingController();

    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Return Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter drop-off details:"),
            const SizedBox(height: 10),
            TextField(controller: locationController, decoration: const InputDecoration(labelText: "Specific Place (e.g. Office)", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: picController, decoration: const InputDecoration(labelText: "PIC Name", border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Confirm")),
        ],
      ),
    );

    if (shouldProceed != true) return;

    String newDesc = "[AT FACULTY: ${item.dropOffNode}]\n📍 Place: ${locationController.text}\n👤 PIC: ${picController.text}\n\n${item.description}";
    
    await Supabase.instance.client.from('items').update({'description': newDesc}).eq('id', item.id);
    
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Item updated!")));
    }
  }

  Future<void> _markAsCollected(BuildContext context) async {
    try {
      await Supabase.instance.client.from('messages').delete().eq('item_id', item.id);
      await Supabase.instance.client.from('items').delete().eq('id', item.id);
      if (context.mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Case Solved! 🎉")));
      }
    } catch (_) {}
  }

  void _verifyAndClaim(BuildContext context) {
    if (item.verificationQuestion == null) {
      _openChat(context, verifiedFirstTry: false);
      return;
    }
    // ... verification logic ...
    _openChat(context, verifiedFirstTry: false);
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
                automaticallyImplyLeading: false, // FIX: Removes the default back button
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
                          color: isAtFaculty ? Colors.green.shade50 : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isAtFaculty ? Colors.green : Colors.blue),
                        ),
                        child: Column(
                          children: [
                            Text(isAtFaculty ? "Ready for Collection at:" : "Return to:", style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(item.dropOffNode!, style: const TextStyle(fontSize: 16)),
                            if (!isAtFaculty)
                              ElevatedButton.icon(
                                icon: const Icon(Icons.map, size: 16),
                                label: const Text("Open in Google Maps"),
                                onPressed: _launchMaps, // FIX: Opens Google Maps
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
          // Custom Back Button (The only one that remains)
          Positioned(
            top: 50, left: 20, 
            child: GestureDetector(
              onTap: () => Navigator.pop(context), 
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                child: const Icon(Icons.arrow_back, color: Colors.black)
              )
            )
          ),
        ],
      ),
    );
  }
}