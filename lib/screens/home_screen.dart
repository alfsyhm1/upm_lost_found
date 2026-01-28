import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'report_screen.dart';
import '../widgets/item_card.dart';
import '../models/item_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('UPM Lost & Found'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "LOST ITEMS"),
              Tab(text: "FOUND ITEMS"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildList('lost'),  
            _buildList('found'), 
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFFB30000),
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen()));
          },
        ),
      ),
    );
  }

  Widget _buildList(String type) {
    final stream = Supabase.instance.client
        .from('items')
        .stream(primaryKey: ['id'])
        .eq('type', type) 
        .order('created_at', ascending: false);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final items = snapshot.data!.map((e) => Item.fromMap(e)).toList();
        
        // --- PULL TO REFRESH LOGIC ---
        return RefreshIndicator(
          onRefresh: () async {
            // Trigger a UI rebuild which essentially "refreshes" the stream listener
            await Future.delayed(const Duration(milliseconds: 800));
          },
          child: items.isEmpty
              ? ListView( // Using ListView ensures pull-to-refresh works even when empty
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.7,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(type == 'lost' ? Icons.search_off : Icons.check_circle_outline, size: 60, color: Colors.grey),
                            const SizedBox(height: 10),
                            Text("No $type items reported yet."),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: items.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) => ItemCard(item: items[index]),
                ),
        );
      },
    );
  }
}