class Item {
  final String id;
  final String title;
  final String description;
  final String type; // 'lost' or 'found'
  final List<String> imageUrls; // Changed from String to List<String>
  final String category;
  final double? locationLat;
  final double? locationLng;
  final String locationName;
  final String? dropOffNode;
  final String? contactNumber;
  final String? reportedBy;
  final String? reportedUsername; // New
  final String? verificationQuestion; // New
  final String? verificationAnswer; // New
  final DateTime createdAt;

  Item({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.imageUrls,
    required this.category,
    this.locationLat,
    this.locationLng,
    required this.locationName,
    this.dropOffNode,
    this.contactNumber,
    this.reportedBy,
    this.reportedUsername,
    this.verificationQuestion,
    this.verificationAnswer,
    required this.createdAt,
  });

  factory Item.fromMap(Map<String, dynamic> data) {
    return Item(
      id: data['id']?.toString() ?? '',
      title: data['title'] ?? 'Unknown Item',
      description: data['description'] ?? '',
      type: data['type'] ?? 'lost',
      // Handles both old (single string) and new (list) image formats
      imageUrls: data['image_urls'] != null 
          ? List<String>.from(data['image_urls']) 
          : (data['image_url'] != null ? [data['image_url']] : []), 
      category: data['category'] ?? 'Other',
      locationLat: data['location_lat']?.toDouble(),
      locationLng: data['location_lng']?.toDouble(),
      locationName: data['location_name'] ?? '',
      dropOffNode: data['drop_off_node'],
      contactNumber: data['contact_number'],
      reportedBy: data['reported_by'],
      reportedUsername: data['reported_username'],
      verificationQuestion: data['verification_question'],
      verificationAnswer: data['verification_answer'],
      createdAt: data['created_at'] != null 
          ? DateTime.parse(data['created_at']) 
          : DateTime.now(),
    );
  }
}