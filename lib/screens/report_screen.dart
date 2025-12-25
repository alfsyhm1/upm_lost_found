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
import '../models/item_model.dart'; 

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  int _currentStep = 0;
  String _type = 'found';
  List<File> _images = [];
  bool _loading = false;
  
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _questionController = TextEditingController(); 
  
  // Multiple Choice Logic
  final List<TextEditingController> _optionControllers = [TextEditingController(), TextEditingController(), TextEditingController()];
  int _correctOptionIndex = 0;

  String _category = 'Other';
  double? _lat;
  double? _lng;
  String? _suggestedDropOff;
  List<Item> _similarItems = [];

  final List<String> _categories = ['Electronics', 'Clothing', 'Wallet', 'Keys', 'Documents', 'Accessories', 'Other'];

  // --- UI: High Contrast Back Button ---
  Widget _buildHeader() {
    return Positioned(
      top: 50, left: 20,
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: CircleAvatar(
          backgroundColor: Colors.white.withOpacity(0.8),
          child: const Icon(Icons.arrow_back, color: Colors.black),
        ),
      ),
    );
  }

  // --- STEP 1: SELECTION ---
  Widget _buildSelectionStep() {
    return Scaffold(
      appBar: AppBar(title: const Text("New Report")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("What would you like to report?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
    
    // Show Source Options
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        height: 250,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Add photos of the $type item?", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text("Take Photo (Camera)"),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.purple),
              title: const Text("Choose from Gallery"),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
            ),
            if (type == 'lost')
              ListTile(
                leading: const Icon(Icons.edit_note, color: Colors.grey),
                title: const Text("No photo, I'll describe it"),
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

  // --- STEP 2: IMAGE PICKER & AI ---
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      if (source == ImageSource.gallery) {
        final picked = await picker.pickMultiImage();
        if (picked.isNotEmpty) {
          setState(() => _images = picked.map((e) => File(e.path)).toList());
          // Delay to allow UI to settle before AI runs
          if (mounted) {
             await Future.delayed(const Duration(milliseconds: 500));
             _analyzeImages();
          }
        }
      } else {
        final picked = await picker.pickImage(source: source);
        if (picked != null) {
          setState(() => _images.add(File(picked.path)));
          if (mounted) {
             await Future.delayed(const Duration(milliseconds: 500));
             _analyzeImages();
          }
        }
      }
    } catch (e) {
      debugPrint("Image Picker Error: $e");
    }
  }

  Future<void> _analyzeImages() async {
    if (_images.isEmpty) return;
    setState(() => _loading = true);

    try {
      final inputImage = InputImage.fromFile(_images.first);
      final labeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.5));
      final labels = await labeler.processImage(inputImage);
      labeler.close();

      final palette = await PaletteGenerator.fromImageProvider(FileImage(_images.first));
      String colorInfo = "Unknown Color";
      if (palette.dominantColor != null) {
        colorInfo = palette.dominantColor!.color.computeLuminance() > 0.5 ? "Light/White" : "Dark/Black";
      }

      setState(() => _loading = false);

      // Default to "Item" if AI finds nothing, ensuring the dialog ALWAYS opens
      String detectedName = labels.isNotEmpty ? labels.first.label : "Item";
      
      if (!mounted) return;

      // 1. Ask Name
      String finalName = await _askAIQuestion("AI identified this as '$detectedName'. Is that correct?", detectedName);
      _titleController.text = finalName;
      _autoCategorize(finalName);

      // 2. Ask Color
      String finalColor = await _askAIQuestion("Is the main color '$colorInfo'?", colorInfo);
      
      // 3. Ask Details
      String tags = labels.isNotEmpty 
          ? labels.take(3).map((l) => l.label).join(', ') 
          : "No specific tags";
      String finalDetails = await _askAIQuestion("AI detected these details: '$tags'. Add to description?", tags);

      // 4. Auto-fill Description
      _descController.text = "Item: $finalName\nColor: $finalColor\nDetails: $finalDetails";

      // 5. Proceed
      setState(() => _currentStep = 1);
      _getSmartLocation();
      _checkForSimilarItems(finalName);

    } catch (e) {
      debugPrint("AI Error: $e");
      setState(() { _loading = false; _currentStep = 1; });
    }
  }

  Future<String> _askAIQuestion(String question, String initialValue) async {
    String value = initialValue;
    await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (ctx) {
        TextEditingController correctionCtrl = TextEditingController();
        bool isWrong = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("AI Smart Check 🤖"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(question, style: const TextStyle(fontSize: 16)),
                  if (isWrong)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TextField(
                        controller: correctionCtrl,
                        decoration: const InputDecoration(labelText: "Type correct detail", border: OutlineInputBorder()),
                      ),
                    )
                ],
              ),
              actions: [
                if (!isWrong)
                  TextButton(
                    onPressed: () => setDialogState(() => isWrong = true), 
                    child: const Text("No, correct it", style: TextStyle(color: Colors.red)),
                  ),
                ElevatedButton(
                  onPressed: () {
                    if (isWrong && correctionCtrl.text.isNotEmpty) {
                      value = correctionCtrl.text;
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text("Confirm"),
                )
              ],
            );
          }
        );
      },
    );
    return value;
  }

  Future<void> _checkForSimilarItems(String query) async {
    try {
      final response = await Supabase.instance.client
          .from('items')
          .select()
          .eq('type', _type == 'lost' ? 'found' : 'lost') // Opposite
          .ilike('title', '%$query%')
          .limit(3);

      if (response.isNotEmpty) {
        setState(() {
          _similarItems = (response as List).map((e) => Item.fromMap(e)).toList();
        });
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Potential matches found!"), backgroundColor: Colors.orange));
      }
    } catch (e) { debugPrint("Search Error: $e"); }
  }

  void _autoCategorize(String label) {
    label = label.toLowerCase();
    if (label.contains('phone') || label.contains('laptop')) _category = 'Electronics';
    else if (label.contains('wallet') || label.contains('card')) _category = 'Wallet';
    else if (label.contains('key')) _category = 'Keys';
  }

  Future<void> _getSmartLocation() async {
    if (_locationController.text.isNotEmpty) return;
    setState(() => _loading = true);
    try {
      Position pos = await Geolocator.getCurrentPosition();
      _lat = pos.latitude;
      _lng = pos.longitude;
      List<Placemark> places = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (places.isNotEmpty) _locationController.text = "${places.first.name}, ${places.first.street}";
      
      if (_type == 'found') {
        String nearestId = findNearestFacultyId(latLng.LatLng(pos.latitude, pos.longitude));
        _suggestedDropOff = getFacultyName(nearestId);
      }
    } catch (e) { /* */ } finally { setState(() => _loading = false); }
  }

  Future<void> _submit() async {
    if (_titleController.text.isEmpty) return;
    setState(() => _loading = true);
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      
      // Upload Images
      List<String> uploadedUrls = [];
      for (var img in _images) {
        final path = 'images/${user?.id}_${DateTime.now().millisecondsSinceEpoch}_${uploadedUrls.length}.jpg';
        await Supabase.instance.client.storage.from('images').upload(path, img);
        uploadedUrls.add(Supabase.instance.client.storage.from('images').getPublicUrl(path));
      }

      // Prepare Security Options
      List<String> options = [];
      String? answer;
      if (_type == 'found' && _questionController.text.isNotEmpty) {
        options = _optionControllers.map((c) => c.text).where((t) => t.isNotEmpty).toList();
        if (options.isNotEmpty) {
          answer = options[_correctOptionIndex]; // The correct one
        }
      }

      String username = "Anonymous";
      try {
        final profile = await Supabase.instance.client.from('profiles').select('username').eq('id', user!.id).maybeSingle();
        if (profile != null) username = profile['username'] ?? "Anonymous";
      } catch (_) {}

      await Supabase.instance.client.from('items').insert({
        'title': _titleController.text,
        'description': _descController.text,
        'type': _type,
        'category': _category,
        'image_urls': uploadedUrls,
        'location_lat': _lat,
        'location_lng': _lng,
        'location_name': _locationController.text,
        'reported_by': user!.id,
        'reported_username': username,
        'drop_off_node': _type == 'found' ? _suggestedDropOff : null,
        // New Security Fields
        'verification_question': _questionController.text.isEmpty ? null : _questionController.text,
        'verification_options': options,
        'verification_answer': answer,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Published!")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStep == 0) return _buildSelectionStep();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Stack(
        children: [
          _loading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Horizontal Image Scroll
                if (_images.isNotEmpty)
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _images.length,
                      itemBuilder: (ctx, i) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_images[i])),
                      ),
                    ),
                  ),
                
                // Matches Alert
                if (_similarItems.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 20),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      children: [
                        const Text("Wait! Is one of these yours?", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                        ..._similarItems.map((item) => ListTile(title: Text(item.title), subtitle: Text(item.locationName))).toList()
                      ],
                    ),
                  ),

                const SizedBox(height: 20),
                _buildTextField("Item Name", _titleController),
                const SizedBox(height: 10),
                DropdownButtonFormField(
                  value: _category,
                  decoration: const InputDecoration(labelText: "Category", filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _category = v.toString()),
                ),
                const SizedBox(height: 10),
                _buildTextField("Description", _descController, lines: 3),
                const SizedBox(height: 10),
                _buildTextField("Location", _locationController, icon: Icons.map),
                
                // Multiple Choice Security Setup
                if (_type == 'found') ...[
                  const SizedBox(height: 30),
                  const Text("🔒 Security Question (Multiple Choice)", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _buildTextField("Question (e.g. What is the wallpaper?)", _questionController),
                  const SizedBox(height: 10),
                  const Text("Enter 3 Options & Select Correct One:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ...List.generate(3, (index) => RadioListTile(
                    title: TextField(controller: _optionControllers[index], decoration: InputDecoration(hintText: "Option ${index + 1}")),
                    value: index,
                    groupValue: _correctOptionIndex,
                    onChanged: (v) => setState(() => _correctOptionIndex = v as int),
                  )),
                ],

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity, 
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _submit, 
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                    child: const Text("Post Report", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          _buildHeader(), // High contrast back button
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController c, {int lines = 1, IconData? icon}) {
    return TextField(
      controller: c, maxLines: lines,
      decoration: InputDecoration(
        labelText: label, prefixIcon: icon != null ? Icon(icon) : null,
        filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))
      ),
    );
  }
}