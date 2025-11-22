import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/item_model.dart';
import '../widgets/item_card.dart';

class AiAssistScreen extends StatefulWidget {
  const AiAssistScreen({super.key});

  @override
  State<AiAssistScreen> createState() => _AiAssistScreenState();
}

class _AiAssistScreenState extends State<AiAssistScreen> {
  int step = 0;
  String? selectedCategory;
  List<Item> matchedItems = [];
  bool loading = false;

  final List<String> categories = ['Electronics', 'Keys', 'Wallet', 'Clothing', 'Documents'];

  void _selectCategory(String category) async {
    setState(() {
      selectedCategory = category;
      loading = true;
      step = 1;
    });

    // Simulate AI Search delay
    await Future.delayed(const Duration(seconds: 1));

    // Fetch matching found items
    final res = await Supabase.instance.client
        .from('items')
        .select()
        .eq('type', 'found')
        .eq('category', category) // Ensure DB has 'category' column
        .order('created_at', ascending: false);

    setState(() {
      matchedItems = (res as List).map((e) => Item.fromMap(e)).toList();
      loading = false;
      step = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Smart Find")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Chat Bubble
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  const Icon(Icons.smart_toy, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      step == 0 
                        ? "Hello! I can help you find your lost item. What did you lose?" 
                        : step == 1 
                          ? "Searching the database for $selectedCategory..." 
                          : "Here are the items I found matching your description.",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Step 0: Categories
            if (step == 0)
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 2.5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: categories.map((c) => ElevatedButton(
                    onPressed: () => _selectCategory(c),
                    child: Text(c),
                  )).toList(),
                ),
              ),

            // Step 1: Loading
            if (step == 1)
              const Expanded(child: Center(child: CircularProgressIndicator())),

            // Step 2: Results
            if (step == 2)
              Expanded(
                child: matchedItems.isEmpty
                    ? const Center(child: Text("No matches found yet. I'll alert you if one appears!"))
                    : ListView.builder(
                        itemCount: matchedItems.length,
                        itemBuilder: (ctx, i) => ItemCard(item: matchedItems[i]),
                      ),
              ),
              
            if (step == 2)
              TextButton(
                onPressed: () => setState(() => step = 0),
                child: const Text("Start Over"),
              )
          ],
        ),
      ),
    );
  }
}