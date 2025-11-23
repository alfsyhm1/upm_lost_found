class Item {
  final String id;
  final String title;
  final String description;
  final String type; // 'lost' or 'found'
  final String imageUrl;
  final String category;
  final double? locationLat;
  final double? locationLng;
  final String locationName;
  final String? dropOffNode;
  final String? reportedBy;
  final String? contactNumber; // <--- This is crucial for the smart features
  final DateTime createdAt;

  Item({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.imageUrl,
    required this.category,
    this.locationLat,
    this.locationLng,
    required this.locationName,
    this.dropOffNode,
    this.reportedBy,
    this.contactNumber,
    required this.createdAt,
  });

  factory Item.fromMap(Map<String, dynamic> data) {
    return Item(
      id: data['id']?.toString() ?? '',
      title: data['title'] ?? 'Unknown Item',
      description: data['description'] ?? '',
      type: data['type'] ?? 'lost',
      imageUrl: data['image_url'] ?? '',
      category: data['category'] ?? 'Other',
      locationLat: data['location_lat'] != null ? (data['location_lat'] as num).toDouble() : null,
      locationLng: data['location_lng'] != null ? (data['location_lng'] as num).toDouble() : null,
      locationName: data['location_name'] ?? '',
      dropOffNode: data['drop_off_node'],
      reportedBy: data['reported_by'],
      contactNumber: data['contact_number'], // <--- Map this field
      createdAt: data['created_at'] != null 
          ? DateTime.parse(data['created_at']) 
          : DateTime.now(),
    );
  }
}