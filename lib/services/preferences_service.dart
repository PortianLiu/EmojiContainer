import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _keyRootDirectory = 'root_directory';

  Future<String?> getRootDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRootDirectory);
  }

  Future<void> setRootDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRootDirectory, path);
  }

  Future<void> clearRootDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRootDirectory);
  }
}
