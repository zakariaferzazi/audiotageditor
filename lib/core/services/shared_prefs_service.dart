import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPrefsServiceProvider = Provider<SharedPrefsService>((ref) {
  throw UnimplementedError('Initialize SharedPrefsService');
});

class SharedPrefsService {
  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  bool? getBool(String key) => _prefs.getBool(key);
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  int? getInt(String key) => _prefs.getInt(key);
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  List<String>? getStringList(String key) => _prefs.getStringList(key);
  Future<void> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);
}
