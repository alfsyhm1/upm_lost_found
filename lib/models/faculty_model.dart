class FacultyNode {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  FacultyNode(this.id, this.name, this.latitude, this.longitude);
}

// Updated UPM Nodes with "Faculty of Science" and others
final List<FacultyNode> facultyNodes = [
  // each line creates one physical location of the faculty
  FacultyNode("FSKTM", "Fac. Computer Science (FSKTM)", 2.9927, 101.7059),
  FacultyNode("FP", "Fac. Agriculture (FP)", 2.9936, 101.7072),
  FacultyNode("FEP", "School of Business (FEP)", 2.9915, 101.7088),
  FacultyNode("FPP", "Fac. Educational Studies (FPP)", 2.9903, 101.7094),
  FacultyNode("FS", "Faculty of Science (FS)", 2.9970, 101.7070), // New
  FacultyNode("Library", "Main Library", 2.9950, 101.7065),
];