import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:latlong2/latlong.dart' as latLng;
import '../services/dijkstra_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  int _currentStep = 0;
  String _type = 'found';
  List<File> _images = []; // Multiple images
  bool _loading = false;
  
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _contactController = TextEditingController();
  final _questionController = TextEditingController(); // Security Question
  final _answerController = TextEditingController();   // Security Answer
  
  String _category = 'Other';
  double? _lat;
  double? _lng;
  String? _suggestedDropOff;
  
  final List<String> _categories = ['Electronics', 'Clothing', 'Wallet', 'Keys', 'Documents', 'Accessories', 'Other'];

  // --- STEP 1: SELECTION ---
  Widget _buildSelectionStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("What do you want to report?", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _selectionButton("Found Item", Icons.volunteer_activism, Colors.blue, 'found'),
              _selectionButton("Lost Item", Icons.search, Colors.red, 'lost'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _selectionButton(String text, IconData icon, Color color, String type) {
    return GestureDetector(
      onTap: () {
        setState(() => _type = type);
        _pickImages(); // Start by picking images
      },
      child: Container(
        width: 160, height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))],
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 16),
            Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  // --- STEP 2: IMAGES & AI ---
  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isEmpty) {
      // If user cancels, proceed to form anyway
      setState(() => _currentStep = 1);
      _getSmartLocation();
      return;
    }

    setState(() {
      _images = picked.map((e) => File(e.path)).toList();
      _loading = true;
    });

    try {
      // Analyze first image for AI
      final inputImage = InputImage.fromFile(_images.first);
      final labeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.5));
      final labels = await labeler.processImage(inputImage);
      labeler.close();

      final palette = await PaletteGenerator.fromImageProvider(FileImage(_images.first));
      String colorInfo = "Unknown Color";
      if (palette.dominantColor != null) {
        colorInfo = palette.dominantColor!.color.computeLuminance() > 0.5 ? "Light" : "Dark";
      }

      if (labels.isNotEmpty) {
        String detected = labels.first.label;
        _titleController.text = detected;
        _descController.text = "Color appears to be $colorInfo. \nTags: ${labels.take(3).map((l) => l.label).join(', ')}";
        _autoCategorize(detected);
      }
    } catch (e) {
      debugPrint("AI Error: $e");
    } finally {
      setState(() {
        _loading = false;
        _currentStep = 1;
      });
      _getSmartLocation();
    }
  }

  void _autoCategorize(String label) {
    label = label.toLowerCase();
    if (label.contains('phone') || label.contains('computer')) _category = 'Electronics';
    else if (label.contains('wallet') || label.contains('card')) _category = 'Wallet';
    else if (label.contains('key')) _category = 'Keys';
  }

  Future<void> _getSmartLocation() async {
    if (_locationController.text.isNotEmpty) return;
    try {
      Position pos = await Geolocator.getCurrentPosition();
      _lat = pos.latitude;
      _lng = pos.longitude;
      List<Placemark> places = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (places.isNotEmpty) {
        _locationController.text = "${places.first.name}, ${places.first.street}";
      }
      if (_type == 'found') {
        String nearestId = findNearestFacultyId(latLng.LatLng(pos.latitude, pos.longitude));
        _suggestedDropOff = getFacultyName(nearestId);
      }
    } catch (e) { /* Ignore */ }
  }

  // --- STEP 3: FORM ---
  Future<void> _submit() async {
    if (_titleController.text.isEmpty) return;
    setState(() => _loading = true);
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      
      // Upload All Images
      List<String> uploadedUrls = [];
      for (var img in _images) {
        final path = 'images/${DateTime.now().millisecondsSinceEpoch}_${uploadedUrls.length}.jpg';
        await Supabase.instance.client.storage.from('images').upload(path, img);
        uploadedUrls.add(Supabase.instance.client.storage.from('images').getPublicUrl(path));
      }

      // Get Username
      final profile = await Supabase.instance.client.from('profiles').select('username').eq('id', user!.id).single();
      String username = profile['username'] ?? "Anonymous";

      await Supabase.instance.client.from('items').insert({
        'title': _titleController.text,
        'description': _descController.text,
        'type': _type,
        'category': _category,
        'image_urls': uploadedUrls, // Array
        'contact_number': _contactController.text,
        'location_lat': _lat,
        'location_lng': _lng,
        'location_name': _locationController.text,
        'reported_by': user.id,
        'reported_username': username,
        'verification_question': _questionController.text.isEmpty ? null : _questionController.text,
        'verification_answer': _answerController.text.isEmpty ? null : _answerController.text,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Published successfully!")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStep == 0) return Scaffold(appBar: AppBar(title: const Text("New Report")), body: _buildSelectionStep());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), // Apple grey background
      appBar: AppBar(title: const Text("Details"), backgroundColor: Colors.transparent, elevation: 0),
      body: _loading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Scroll
            if (_images.isNotEmpty)
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length + 1,
                  itemBuilder: (ctx, i) {
                    if (i == _images.length) {
                      return GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          width: 100, margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.add_a_photo, color: Colors.grey),
                        ),
                      );
                    }
                    return Container(
                      margin: const EdgeInsets.only(right: 10),
                      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_images[i], width: 120, fit: BoxFit.cover)),
                    );
                  },
                ),
              ),
            
            const SizedBox(height: 20),
            _inputField("Item Name", _titleController),
            _inputField("Description", _descController, lines: 3),
            _inputField("Location", _locationController, icon: Icons.map),
            _inputField("Contact (WhatsApp)", _contactController, icon: Icons.phone),

            // SECURITY SECTION (Anti-Theft)
            if (_type == 'found') ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("🔒 Anti-Theft Security", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(height: 5),
                    const Text("Set a question only the owner can answer. (e.g., 'What is the wallpaper?')", style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 10),
                    TextField(controller: _questionController, decoration: const InputDecoration(hintText: "Security Question", border: OutlineInputBorder(), filled: true, fillColor: Colors.white)),
                    const SizedBox(height: 10),
                    TextField(controller: _answerController, decoration: const InputDecoration(hintText: "Correct Answer", border: OutlineInputBorder(), filled: true, fillColor: Colors.white)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("Post Report", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField(String label, TextEditingController ctrl, {int lines = 1, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        maxLines: lines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}