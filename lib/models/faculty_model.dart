class FacultyNode {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  FacultyNode(this.id, this.name, this.latitude, this.longitude);
}

// Example coordinates for main UPM faculties (adjust as needed)
final List<FacultyNode> facultyNodes = [
  FacultyNode("FSKTM", "Computer Science", 2.9927, 101.7059),
  FacultyNode("FP", "Faculty of Agriculture", 2.9936, 101.7072),
  FacultyNode("FEP", "Faculty of Economics", 2.9915, 101.7088),
  FacultyNode("FPP", "Faculty of Food Science", 2.9903, 101.7094),
];
