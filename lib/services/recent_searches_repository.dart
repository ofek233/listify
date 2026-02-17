import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recent_search.dart';

/// Repository for managing recent search history
/// Uses shared_preferences to persist searches locally
class RecentSearchesRepository {
  static const String _storageKey = 'recent_searches';
  static const int _maxRecentSearches = 5;

  late SharedPreferences _prefs;
  bool _initialized = false;

  /// Initialize the repository
  Future<void> init() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    }
  }

  /// Ensure initialization before operations
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }

  /// Add a search query to recent searches
  /// Removes duplicates and maintains max limit of 5 searches
  Future<void> addSearch(RecentSearch search) async {
    await _ensureInitialized();

    try {
      // Get existing searches
      final searches = await getRecentSearches();

      // Remove duplicate query if it exists
      searches.removeWhere((s) => s.query.toLowerCase() == search.query.toLowerCase());

      // Add new search to the front
      searches.insert(0, search);

      // Keep only the most recent N searches
      if (searches.length > _maxRecentSearches) {
        searches.removeRange(_maxRecentSearches, searches.length);
      }

      // Save to preferences
      await _saveSearches(searches);
    } catch (e) {
      print('Error adding search: $e');
    }
  }

  /// Get the list of recent searches (up to 5, in chronological order)
  Future<List<RecentSearch>> getRecentSearches() async {
    await _ensureInitialized();

    try {
      final jsonString = _prefs.getString(_storageKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList
          .map((item) => RecentSearch.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error retrieving recent searches: $e');
      return [];
    }
  }

  /// Clear all search history
  Future<void> clearHistory() async {
    await _ensureInitialized();

    try {
      await _prefs.remove(_storageKey);
    } catch (e) {
      print('Error clearing search history: $e');
    }
  }

  /// Remove a specific search from history
  Future<void> removeSearch(String query) async {
    await _ensureInitialized();

    try {
      final searches = await getRecentSearches();
      searches.removeWhere((s) => s.query.toLowerCase() == query.toLowerCase());
      await _saveSearches(searches);
    } catch (e) {
      print('Error removing search: $e');
    }
  }

  /// Save list of searches to preferences
  Future<void> _saveSearches(List<RecentSearch> searches) async {
    try {
      final jsonList = searches.map((s) => s.toMap()).toList();
      final jsonString = jsonEncode(jsonList);
      await _prefs.setString(_storageKey, jsonString);
    } catch (e) {
      print('Error saving searches: $e');
    }
  }
}
