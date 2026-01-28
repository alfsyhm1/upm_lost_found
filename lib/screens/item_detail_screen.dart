import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../models/item_model.dart';
import '../models/faculty_model.dart'; 
import 'chat_screen.dart';

// CHANGED TO STATEFUL WIDGET TO TRACK "FAILED ATTEMPTS"
class ItemDetailScreen extends StatefulWidget {
  final Item item;
  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  // Track if user ever guessed wrong during this session
  bool _hasFailedAttempt = false;

  Future<void> _launchMaps() async {
    try {
      final node = facultyNodes.firstWhere((n) => n.name == widget.item.dropOffNode);
      final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=${node.latitude},${node.longitude}");
      
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch maps';
      }
    } catch (e) {
      final fallbackUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(widget.item.dropOffNode ?? 'UPM')}");
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

    String newDesc = "[AT FACULTY: ${widget.item.dropOffNode}]\n📍 Place: ${locationController.text}\n👤 PIC: ${picController.text}\n\n${widget.item.description}";
    
    await Supabase.instance.client.from('items').update({'description': newDesc}).eq('id', widget.item.id);
    
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Item updated!")));
    }
  }

  Future<void> _markAsCollected(BuildContext context) async {
    try {
      await Supabase.instance.client.from('messages').delete().eq('item_id', widget.item.id);
      await Supabase.instance.client.from('items').delete().eq('id', widget.item.id);
      if (context.mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Case Solved! 🎉")));
      }
    } catch (_) {}
  }

  // --- VERIFICATION LOGIC ---
  void _verifyAndClaim(BuildContext context) {
    // Case 1: No Question set? Just open chat.
    if (widget.item.verificationQuestion == null || widget.item.verificationQuestion!.isEmpty) {
      _openChat(context, verifiedFirstTry: false);
      return;
    }

    TextEditingController answerCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Security Check 🔒"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("To claim this item, please answer the finder's question:"),
            const SizedBox(height: 10),
            Text(widget.item.verificationQuestion!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            
            // Multiple Choice UI
            if (widget.item.verificationOptions.isNotEmpty) 
              ...widget.item.verificationOptions.map((opt) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, 
                    foregroundColor: Colors.black,
                    elevation: 0,
                    side: const BorderSide(color: Colors.grey)
                  ),
                  onPressed: () => _checkAnswer(ctx, opt),
                  child: SizedBox(width: double.infinity, child: Text(opt, textAlign: TextAlign.center)),
                ),
              )).toList()
            
            // Text Input UI
            else 
              TextField(
                controller: answerCtrl,
                decoration: const InputDecoration(labelText: "Your Answer", border: OutlineInputBorder()),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          if (widget.item.verificationOptions.isEmpty)
            ElevatedButton(
              onPressed: () => _checkAnswer(ctx, answerCtrl.text),
              child: const Text("Verify"),
            )
        ],
      ),
    );
  }

  void _checkAnswer(BuildContext dialogCtx, String input) {
    // Compare answers (Trim spaces and ignore capitalization)
    final correct = widget.item.verificationAnswer?.trim().toLowerCase() ?? "";
    final attempt = input.trim().toLowerCase();

    if (attempt == correct) {
      Navigator.pop(dialogCtx); // Close dialog only on success
      // If they failed previously, passed 'false' to first try
      _openChat(context, verifiedFirstTry: !_hasFailedAttempt); 
    } else {
      // WRONG ANSWER: Don't close dialog, just show error and flag the user
      setState(() {
        _hasFailedAttempt = true; // Flag them!
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Incorrect Answer! Try again."), backgroundColor: Colors.red)
      );
    }
  }

  void _openChat(BuildContext context, {required bool verifiedFirstTry}) async {
    final myId = Supabase.instance.client.auth.currentUser!.id;
    if (myId == widget.item.reportedBy) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You posted this item!")));
        return;
    }

    // Determine the message based on performance
    String systemMessage = verifiedFirstTry 
        ? "[NOTICE]: Verified Owner! 🛡️" // Green Message
        : "[ALERT]: User claimed this item (Not first guess) ⚠️"; // Warning Message

    try { 
      await Supabase.instance.client.from('messages').insert({
        'sender_id': myId, 
        'receiver_id': widget.item.reportedBy, 
        'item_id': widget.item.id, 
        'content': systemMessage
      }); 
    } catch (_) {}

    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
        otherUserId: widget.item.reportedBy!, 
        otherUserName: widget.item.reportedUsername ?? "User",
        itemId: widget.item.id,
        itemName: widget.item.title,
      )));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final isFinder = myId == widget.item.reportedBy;
    final isAtFaculty = widget.item.description.contains("[AT FACULTY");

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 350,
                automaticallyImplyLeading: false, 
                flexibleSpace: FlexibleSpaceBar(
                  background: widget.item.imageUrls.isNotEmpty
                      ? Image.network(widget.item.imageUrls[0], fit: BoxFit.cover)
                      : Container(color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported, size: 50)),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(widget.item.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    if (widget.item.dropOffNode != null) ...[
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
                            Text(widget.item.dropOffNode!, style: const TextStyle(fontSize: 16)),
                            if (!isAtFaculty)
                              ElevatedButton.icon(
                                icon: const Icon(Icons.map, size: 16),
                                label: const Text("Open in Google Maps"),
                                onPressed: _launchMaps, 
                              )
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    const Text("Description:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(widget.item.description, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 40),
                    
                    if (isFinder) ...[
                      if (!isAtFaculty && widget.item.dropOffNode != null)
                        ElevatedButton(
                          onPressed: () => _markAsReturnedToFaculty(context), 
                          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                          child: const Text("I Returned it to Faculty")
                        ),
                      const SizedBox(height: 10),
                      if (isAtFaculty)
                        ElevatedButton(
                          onPressed: () => _markAsCollected(context), 
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(50)),
                          child: const Text("Mark as Collected & Solve")
                        ),
                    ] else ...[
                      if (!isAtFaculty) 
                        ElevatedButton(
                          onPressed: () => _verifyAndClaim(context), 
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(50)),
                          child: const Text("Claim Item")
                        ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => _openChat(context, verifiedFirstTry: false), 
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                        child: const Text("Chat with Finder")
                      ),
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