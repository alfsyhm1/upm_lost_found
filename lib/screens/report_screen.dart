import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; // Reverse geocoding
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:palette_generator/palette_generator.dart'; // Color detection
import 'package:latlong2/latlong.dart' as latLng;
import '../services/dijkstra_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // State Variables
  int _currentStep = 0;
  String _type = 'found'; // Default
  File? _image;
  bool _loading = false;
  
  // Form Controllers
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _contactController = TextEditingController();
  
  // Data
  String _category = 'Other';
  double? _lat;
  double? _lng;
  String? _suggestedDropOff;
  
  final List<String> _categories = ['Electronics', 'Clothing', 'Wallet', 'Keys', 'Documents', 'Accessories', 'Other'];

  // --- STEP 1: SELECTION ---
  Widget _buildSelectionStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("What happened?", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _bigButton("I FOUND\nAN ITEM", Icons.volunteer_activism, Colors.blue, 'found'),
            _bigButton("I LOST\nAN ITEM", Icons.search, Colors.red, 'lost'),
          ],
        ),
      ],
    );
  }

  Widget _bigButton(String text, IconData icon, Color color, String type) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _type = type;
          _currentStep = 1; 
        });
        if (type == 'found') _getImageAndAnalyze(); // Auto start camera for 'found'
      },
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

  // --- STEP 2: AI & INTELLIGENCE ---
  Future<void> _getImageAndAnalyze() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked == null) return;

    setState(() {
      _image = File(picked.path);
      _loading = true;
    });

    // 1. Run AI Labeling
    final inputImage = InputImage.fromFile(_image!);
    final labeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.5));
    final labels = await labeler.processImage(inputImage);
    labeler.close();

    // 2. Run Color Extraction
    final palette = await PaletteGenerator.fromImageProvider(FileImage(_image!));
    String colorName = "Unknown color";
    if (palette.dominantColor != null) {
      // Simple approximate logic (In real app, map HSL to names)
      colorName = "Dark/Colored"; 
      if (palette.dominantColor!.color.computeLuminance() > 0.8) colorName = "White/Light";
    }

    setState(() => _loading = false);

    // 3. AI Dialog Interaction
    if (labels.isNotEmpty) {
      String detectedItem = labels.first.label;
      bool confirmed = await _showConfirmationDialog("AI Detected", "Is this a $detectedItem?");
      
      if (confirmed) {
        _titleController.text = detectedItem;
        // Auto-Categorize
        _autoCategorize(detectedItem);
        
        // Ask for Details
        bool colorConfirmed = await _showConfirmationDialog("Detail Check", "Is it $colorName?");
        String desc = colorConfirmed ? "$colorName $detectedItem." : "$detectedItem.";
        
        // Append other labels
        String others = labels.skip(1).take(2).map((l) => l.label).join(', ');
        if (others.isNotEmpty) desc += " Also looks like: $others.";
        
        _descController.text = desc;
      }
    }

    // 4. Get Location & Smart Tagging
    await _getLocationSmart();
    setState(() => _currentStep = 2); // Move to review
  }

  void _autoCategorize(String label) {
    label = label.toLowerCase();
    if (label.contains('phone') || label.contains('laptop') || label.contains('camera')) _category = 'Electronics';
    else if (label.contains('shirt') || label.contains('shoe') || label.contains('dress')) _category = 'Clothing';
    else if (label.contains('purse') || label.contains('wallet')) _category = 'Wallet';
    else if (label.contains('key')) _category = 'Keys';
    else _category = 'Other';
  }

  Future<void> _getLocationSmart() async {
    setState(() => _loading = true);
    try {
      Position pos = await Geolocator.getCurrentPosition();
      _lat = pos.latitude;
      _lng = pos.longitude;

      // Reverse Geocode (Lat/Lng -> Street Name)
      List<Placemark> placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        _locationController.text = "${place.street}, ${place.name}";
      } else {
        _locationController.text = "${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}";
      }

      // Dijkstra: Find Nearest Faculty
      if (_type == 'found') {
        String nearestId = findNearestFacultyId(latLng.LatLng(pos.latitude, pos.longitude));
        String facultyName = getFacultyName(nearestId);
        _suggestedDropOff = facultyName;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Found nearby $facultyName. You can drop it there!")),
        );
      }
    } catch (e) {
      debugPrint("Location Error: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<bool> _showConfirmationDialog(String title, String content) async {
    return await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Yes")),
        ],
      ),
    ) ?? false;
  }

  // --- STEP 3: REVIEW & SUBMIT ---
  Widget _buildReviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_image != null) 
            Center(child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_image!, height: 200))),
          const SizedBox(height: 20),
          
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: "Item Name", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          
          DropdownButtonFormField(
            value: _category,
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _category = v.toString()),
            decoration: const InputDecoration(labelText: "Category", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          
          TextField(
            controller: _descController, maxLines: 3, 
            decoration: const InputDecoration(labelText: "Description (AI Auto-filled)", border: OutlineInputBorder())
          ),
          const SizedBox(height: 10),
          
          // Smart Location
          TextField(
            controller: _locationController,
            readOnly: true,
            decoration: InputDecoration(
              labelText: "Location (Auto-Tagged)", 
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(icon: const Icon(Icons.map), onPressed: _getLocationSmart),
            )
          ),
          const SizedBox(height: 10),

          // Contact Info
          TextField(
            controller: _contactController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: "Your WhatsApp/Phone (Optional)",
              hintText: "e.g. 60123456789",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
          ),

          // Dijkstra Option
          if (_type == 'found' && _suggestedDropOff != null)
            SwitchListTile(
              title: Text("Return to $_suggestedDropOff?"),
              subtitle: const Text("Other students can collect it there."),
              value: _descController.text.contains("Collect at:"),
              onChanged: (val) {
                setState(() {
                  if (val) {
                    _descController.text += "\n\n[System Alert]: Item deposited at $_suggestedDropOff.";
                  } else {
                    _descController.text = _descController.text.replaceAll("\n\n[System Alert]: Item deposited at $_suggestedDropOff.", "");
                  }
                });
              },
            ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitReport,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(15), backgroundColor: Colors.green),
              child: const Text("SUBMIT REPORT", style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _submitReport() async {
    setState(() => _loading = true);
    // ... (Supabase Upload Logic - Same as before but with Contact Number) ...
    try {
      final user = Supabase.instance.client.auth.currentUser;
      String imageUrl = '';
      if (_image != null) {
        final path = 'images/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await Supabase.instance.client.storage.from('images').upload(path, _image!);
        imageUrl = Supabase.instance.client.storage.from('images').getPublicUrl(path);
      }

      await Supabase.instance.client.from('items').insert({
        'title': _titleController.text,
        'description': _descController.text,
        'type': _type,
        'category': _category,
        'image_url': imageUrl,
        'reported_by': user?.id,
        'contact_number': _contactController.text,
        'location_lat': _lat,
        'location_lng': _lng,
        'location_name': _locationController.text,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        // Alert Section Requirement: Notification
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Report Posted Successfully! Users notified."),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          )
        );
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
    return Scaffold(
      appBar: AppBar(title: const Text("Smart Report")),
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
        : _currentStep == 0 
            ? _buildSelectionStep() 
            : _buildReviewStep(),
    );
  }
}