class Edge {
  final String to;
  final double weight;
  Edge(this.to, this.weight);
}

final Map<String, List<Edge>> graph = {
  "FSKTM": [Edge("FP", 2.0), Edge("FEP", 1.5)],
  "FP": [Edge("FSKTM", 2.0), Edge("FEP", 1.0), Edge("FPP", 1.2)],
  "FEP": [Edge("FSKTM", 1.5), Edge("FP", 1.0), Edge("FPP", 1.3)],
  "FPP": [Edge("FP", 1.2), Edge("FEP", 1.3)],
};

List<String> dijkstra(String start, String end) {
  final dist = <String, double>{};
  final prev = <String, String?>{};
  final unvisited = <String>{};

  for (var node in graph.keys) {
    dist[node] = double.infinity;
    prev[node] = null;
    unvisited.add(node);
  }
  dist[start] = 0;

  while (unvisited.isNotEmpty) {
    String current =
        unvisited.reduce((a, b) => dist[a]! < dist[b]! ? a : b);
    unvisited.remove(current);

    if (current == end) break;

    for (var edge in graph[current]!) {
      double alt = dist[current]! + edge.weight;
      if (alt < dist[edge.to]!) {
        dist[edge.to] = alt;
        prev[edge.to] = current;
      }
    }
  }

  final path = <String>[];
  String? u = end;
  while (u != null) {
    path.insert(0, u);
    u = prev[u];
  }

  return path;
}
