import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/item_model.dart';
import '../widgets/item_card.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<Item> matchedItems = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkMatches();
  }

  Future<void> _checkMatches() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      // 1. Get categories of items I LOST
      final myLostItems = await Supabase.instance.client
          .from('items')
          .select('category')
          .eq('reported_by', user.id)
          .eq('type', 'lost');

      if ((myLostItems as List).isEmpty) {
        setState(() => isLoading = false);
        return;
      }

      List<String> myCategories = myLostItems
          .map((e) => e['category'] as String)
          .toSet()
          .toList();

      // 2. Find items OTHERS FOUND in those categories
      // FIX: Use .in_() instead of .inFilter()
        final matches = await Supabase.instance.client
          .from('items')
          .select()
          .eq('type', 'found')
          .inFilter('category', myCategories)
          .neq('reported_by', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          matchedItems = (matches as List).map((e) => Item.fromMap(e)).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Alerts Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Alerts")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : matchedItems.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off, size: 60, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No matches found for your lost items yet."),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: matchedItems.length,
                  itemBuilder: (context, index) {
                    final item = matchedItems[index];
                    return Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.green.shade50,
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(
                                      "Possible match: Someone found a ${item.category}")),
                            ],
                          ),
                        ),
                        ItemCard(item: item),
                      ],
                    );
                  },
                ),
    );
  }
}