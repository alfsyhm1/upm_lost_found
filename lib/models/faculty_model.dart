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
  FacultyNode("FSKTM", "Fac. Computer Science (FSKTM)", 2.9997, 101.7105),  
  FacultyNode("FP", "Fac. Agriculture (FP)", 2.9834, 101.7340),
  FacultyNode("SBE", "School of Business (SBE)", 3.0012, 101.7064),
  FacultyNode("FPP", "Fac. Educational Studies (FPP)", 3.0028, 101.7117),
  FacultyNode("FS", "Faculty of Science (FS)", 3.0006, 101.7051), // New
  FacultyNode("Library", "Main Library", 3.0023, 101.7059),
];