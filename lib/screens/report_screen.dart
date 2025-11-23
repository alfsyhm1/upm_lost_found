import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:latlong2/latlong.dart' as latLng; // Alias to avoid conflicts
import '../services/dijkstra_service.dart';
import '../models/item_model.dart';
import '../screens/item_detail_screen.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // UI State
  int _currentStep = 0; // 0 = Selection, 1 = Details
  String _type = 'found';
  bool _loading = false;
  
  // Data State
  File? _image;
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _contactController = TextEditingController();
  
  String _category = 'Other';
  double? _lat;
  double? _lng;
  String? _suggestedDropOff;
  List<Item> _similarItems = []; // Stores smart matches

  final List<String> _categories = ['Electronics', 'Clothing', 'Wallet', 'Keys', 'Documents', 'Accessories', 'Other'];

  // --- STEP 1: SELECTION SCREEN ---
  Widget _buildSelectionStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("What happened?", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _selectionButton("I FOUND\nAN ITEM", Icons.volunteer_activism, Colors.blue, 'found'),
              _selectionButton("I LOST\nAN ITEM", Icons.search, Colors.red, 'lost'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _selectionButton(String text, IconData icon, Color color, String type) {
    return GestureDetector(
      onTap: () => _handleSelection(type),
      child: Container(
        width: 150, height: 150,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSelection(String type) async {
    setState(() => _type = type);
    if (type == 'found') {
      // Found something? Take a picture immediately.
      await _getImageAndAnalyze(ImageSource.camera);
    } else {
      // Lost something? Ask if they have a photo.
      _showLostItemOptions();
    }
  }

  Future<void> _showLostItemOptions() async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        height: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Do you have a photo of the lost item?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.red),
              title: const Text("Yes, I have an old photo"),
              onTap: () {
                Navigator.pop(ctx);
                _getImageAndAnalyze(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.grey),
              title: const Text("No, I'll describe it"),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _currentStep = 1); 
                _getSmartLocation(); 
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- STEP 2: AI ANALYSIS & MATCHING ---
  Future<void> _getImageAndAnalyze(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) {
      if (_type == 'lost') {
        setState(() => _currentStep = 1);
        _getSmartLocation();
      }
      return;
    }

    setState(() { _image = File(picked.path); _loading = true; });

    try {
      // 1. AI Labeling
      final inputImage = InputImage.fromFile(_image!);
      final labeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.5));
      final labels = await labeler.processImage(inputImage);
      labeler.close();

      // 2. Color Detection
      final palette = await PaletteGenerator.fromImageProvider(FileImage(_image!));
      String colorInfo = "Unknown Color";
      if (palette.dominantColor != null) {
        colorInfo = palette.dominantColor!.color.computeLuminance() > 0.8 ? "Light/White" : "Dark/Colored";
      }

      setState(() => _loading = false);

      String detectedLabel = "";

      if (labels.isNotEmpty) {
        String detected = labels.first.label;
        detectedLabel = detected;
        
        String aiMessage = _type == 'found' 
            ? "AI thinks this is a $detected. Is that correct?" 
            : "Does your lost item look like a $detected?";
            
        bool confirm = await _showDialog("AI Smart Scan", aiMessage);
        
        if (confirm) {
          _titleController.text = detected;
          _descController.text = "Item is $colorInfo. \nAI Tags: ${labels.take(3).map((l) => l.label).join(', ')}";
          _autoCategorize(detected);
        }
      }
      
      // Move to form
      setState(() => _currentStep = 1);
      await _getSmartLocation();
      
      // 3. PROACTIVE MATCHING: Search DB immediately
      if (detectedLabel.isNotEmpty) {
        _checkForSimilarItems(detectedLabel); 
      }

    } catch (e) {
      setState(() => _loading = false);
      debugPrint("AI Error: $e");
      setState(() => _currentStep = 1); 
    }
  }

  // Matches items intelligently based on title/category
  Future<void> _checkForSimilarItems(String query) async {
    String targetType = _type == 'lost' ? 'found' : 'lost'; // Search for the opposite
    
    try {
      final response = await Supabase.instance.client
          .from('items')
          .select()
          .eq('type', targetType)
          .ilike('title', '%$query%') // Fuzzy search
          .limit(3);

      if (response.isNotEmpty) {
        setState(() {
          _similarItems = (response as List).map((e) => Item.fromMap(e)).toList();
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Smart Alert: We found potential matches!"),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            )
          );
        }
      }
    } catch (e) {
      debugPrint("Matching Error: $e");
    }
  }

  void _autoCategorize(String label) {
    label = label.toLowerCase();
    if (label.contains('phone') || label.contains('laptop')) _category = 'Electronics';
    else if (label.contains('wallet') || label.contains('card')) _category = 'Wallet';
    else if (label.contains('key')) _category = 'Keys';
    else if (label.contains('bag')) _category = 'Accessories';
    else if (label.contains('clothing') || label.contains('shirt')) _category = 'Clothing';
  }

  Future<void> _getSmartLocation() async {
    if (_locationController.text.isNotEmpty) return;

    setState(() => _loading = true);
    try {
      Position pos = await Geolocator.getCurrentPosition();
      _lat = pos.latitude;
      _lng = pos.longitude;

      // Reverse Geocode to get street name
      List<Placemark> places = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (places.isNotEmpty) {
        _locationController.text = "${places.first.name}, ${places.first.street}";
      }

      // Dijkstra: Find nearest faculty for found items
      if (_type == 'found') {
        String nearestId = findNearestFacultyId(latLng.LatLng(pos.latitude, pos.longitude));
        _suggestedDropOff = getFacultyName(nearestId);
      }
    } catch (e) {
      debugPrint("Location Error: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<bool> _showDialog(String title, String content) async {
    return await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title), content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Yes")),
        ],
      ),
    ) ?? false;
  }

  Future<void> _submit() async {
    if (_titleController.text.isEmpty) return;
    setState(() => _loading = true);
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      String imageUrl = '';
      
      if (_image != null) {
        final path = 'images/${user?.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await Supabase.instance.client.storage.from('images').upload(path, _image!);
        imageUrl = Supabase.instance.client.storage.from('images').getPublicUrl(path);
      }

      await Supabase.instance.client.from('items').insert({
        'title': _titleController.text,
        'description': _descController.text,
        'type': _type,
        'category': _category,
        'image_url': imageUrl,
        'contact_number': _contactController.text, // Required new field
        'location_lat': _lat,
        'location_lng': _lng,
        'location_name': _locationController.text,
        'reported_by': user?.id,
        'drop_off_node': _type == 'found' ? _suggestedDropOff : null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Report Posted Successfully!")));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStep == 0) {
      return Scaffold(appBar: AppBar(title: const Text("New Report")), body: _buildSelectionStep());
    }

    return Scaffold(
      appBar: AppBar(title: Text(_type == 'found' ? "Found Item" : "Lost Item")),
      body: _loading 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // --- SMART MATCHING ALERT ---
              if (_similarItems.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text("Wait! Is one of these yours?", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _similarItems.length,
                        itemBuilder: (ctx, i) {
                          final item = _similarItems[i];
                          return ListTile(
                            leading: item.imageUrl.isNotEmpty ? Image.network(item.imageUrl, width: 40, height: 40, fit: BoxFit.cover) : const Icon(Icons.image),
                            title: Text(item.title),
                            subtitle: Text(item.locationName),
                            trailing: const Icon(Icons.arrow_forward),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item))),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              // ---------------------------

              GestureDetector(
                onTap: () => _showLostItemOptions(),
                child: _image != null 
                  ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_image!, height: 180, fit: BoxFit.cover))
                  : Container(
                      height: 150, width: double.infinity,
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [Icon(Icons.camera_alt, size: 40), Text("Tap to change photo")],
                      ),
                    ),
              ),
              const SizedBox(height: 20),

              TextField(controller: _titleController, decoration: const InputDecoration(labelText: "Item Name", border: OutlineInputBorder())),
              const SizedBox(height: 10),
              
              DropdownButtonFormField(
                value: _category,
                decoration: const InputDecoration(labelText: "Category", border: OutlineInputBorder()),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _category = v.toString()),
              ),
              const SizedBox(height: 10),

              TextField(controller: _descController, maxLines: 3, decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder())),
              const SizedBox(height: 10),

              TextField(
                controller: _locationController, 
                decoration: InputDecoration(
                  labelText: "Location", 
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(icon: const Icon(Icons.my_location), onPressed: _getSmartLocation),
                )
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _contactController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Phone / WhatsApp",
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
              ),

              if (_type == 'found' && _suggestedDropOff != null)
                Card(
                  color: Colors.green.shade50,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  child: ListTile(
                    leading: const Icon(Icons.place, color: Colors.green),
                    title: Text("Nearest Drop-off: $_suggestedDropOff"),
                    subtitle: const Text("Tap to use this drop-off point"),
                    onTap: () => setState(() => _descController.text += "\n\nItem left at: $_suggestedDropOff"),
                  ),
                ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: _type == 'lost' ? Colors.red : Colors.blue),
                child: Text("SUBMIT ${_type.toUpperCase()} REPORT", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
    );
  }
}