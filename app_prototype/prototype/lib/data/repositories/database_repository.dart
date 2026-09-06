import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseRepository {
  final Map<String, List<List<double>>> _storedVectors = {};
  static const String _dbKey = 'face_database';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final String? dbString = prefs.getString(_dbKey);

    if (dbString != null) {
      final Map<String, dynamic> decoded = jsonDecode(dbString);
      decoded.forEach((key, value) {
        List<List<double>> userVectors = [];
        for (var vec in (value as List)) {
          userVectors
              .add((vec as List).map((e) => (e as num).toDouble()).toList());
        }
        _storedVectors[key] = userVectors;
      });
    }
  }

  Future<void> registerUser(String name, List<double> vector) async {
    if (_storedVectors.containsKey(name)) {
      _storedVectors[name]!.add(vector);
    } else {
      _storedVectors[name] = [vector];
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dbKey, jsonEncode(_storedVectors));
  }

  Map<String, List<List<double>>> getAllUsers() {
    return _storedVectors;
  }

  Future<void> clearAllUsers() async {
    _storedVectors.clear(); // Clear from active memory
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dbKey); // Permanently delete from local storage
  }
}
