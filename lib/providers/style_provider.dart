import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/style_config.dart';

class StyleProvider with ChangeNotifier {
  StyleConfig _currentConfig = StyleConfig(name: 'Défaut');
  List<StyleConfig> _savedConfigs = [];

  StyleProvider() {
    _loadFromPrefs();
  }

  StyleConfig get currentConfig => _currentConfig;
  List<StyleConfig> get savedConfigs => _savedConfigs;

  set currentConfig(StyleConfig config) {
    _currentConfig = config;
    notifyListeners();
  }

  // --- Logic ---

  Color getColorForNote(int keyIndex) {
    bool isBlack = _isBlackKey(keyIndex);

    switch (_currentConfig.mode) {
      case DifferentiationMode.none:
        return _currentConfig.colorA;
      case DifferentiationMode.blackWhite:
        return isBlack ? _currentConfig.colorB : _currentConfig.colorA;
      case DifferentiationMode.split:
        return (keyIndex < _currentConfig.splitKey) 
            ? _currentConfig.colorA 
            : _currentConfig.colorB;
    }
  }

  bool _isBlackKey(int index) {
    int n = (index + 9) % 12;
    return [1, 3, 6, 8, 10].contains(n);
  }

  // --- Persistence ---

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Saved Configs
    final String? savedJson = prefs.getString('saved_styles');
    if (savedJson != null) {
      final List decoded = jsonDecode(savedJson);
      _savedConfigs = decoded.map((j) => StyleConfig.fromJson(j)).toList();
    }

    // Load Active Config (Optional: persistence of current selection)
    final String? activeJson = prefs.getString('active_style');
    if (activeJson != null) {
      _currentConfig = StyleConfig.fromJson(jsonDecode(activeJson));
    }
    
    notifyListeners();
  }

  Future<void> saveCurrentConfig(String name) async {
    final newConfig = _currentConfig.copyWith(name: name);
    
    // Check if already exists (by name) and replace
    int existingIndex = _savedConfigs.indexWhere((c) => c.name == name);
    if (existingIndex != -1) {
      _savedConfigs[existingIndex] = newConfig;
    } else {
      _savedConfigs.add(newConfig);
    }

    await _persist();
    notifyListeners();
  }

  Future<void> deleteConfig(StyleConfig config) async {
    _savedConfigs.removeWhere((c) => c.name == config.name);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final String savedJson = jsonEncode(_savedConfigs.map((c) => c.toJson()).toList());
    await prefs.setString('saved_styles', savedJson);
    await prefs.setString('active_style', jsonEncode(_currentConfig.toJson()));
  }

  Future<void> applyConfig(StyleConfig config) async {
    _currentConfig = config;
    await _persist();
    notifyListeners();
  }
}
