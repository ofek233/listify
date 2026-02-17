/// Represents a single recent search entry for history tracking
class RecentSearch {
  final String query;
  final DateTime timestamp;
  final int resultCount;

  RecentSearch({
    required this.query,
    required this.timestamp,
    this.resultCount = 0,
  });

  /// Returns a formatted display string of how long ago this search was performed
  String getTimeAgoString() {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).ceil()}w ago';
    }
  }

  /// Convert to map for JSON serialization (for shared_preferences)
  Map<String, dynamic> toMap() {
    return {
      'query': query,
      'timestamp': timestamp.toIso8601String(),
      'resultCount': resultCount,
    };
  }

  /// Create from map for JSON deserialization
  factory RecentSearch.fromMap(Map<String, dynamic> map) {
    return RecentSearch(
      query: map['query'] ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      resultCount: map['resultCount'] ?? 0,
    );
  }

  @override
  String toString() =>
      'RecentSearch(query: "$query", resultCount: $resultCount, timestamp: $timestamp)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RecentSearch &&
        other.query == query &&
        other.timestamp == timestamp &&
        other.resultCount == resultCount;
  }

  @override
  int get hashCode =>
      query.hashCode ^ timestamp.hashCode ^ resultCount.hashCode;
}
