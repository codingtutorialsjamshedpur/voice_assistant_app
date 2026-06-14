class QueryItem {
  final String text;
  final String category; // e.g. 'sports', 'science', 'history'
  final DateTime timestamp;

  const QueryItem({
    required this.text,
    required this.category,
    required this.timestamp,
  });
}
