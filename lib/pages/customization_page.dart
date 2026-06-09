import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../providers/style_provider.dart';
import '../models/style_config.dart';

class CustomizationPage extends StatelessWidget {
  const CustomizationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final styleProvider = Provider.of<StyleProvider>(context);
    final config = styleProvider.currentConfig;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Personnalisation des Notes"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () => _showSaveDialog(context, styleProvider),
          ),
        ],
      ),
      body: Row(
        children: [
          // Left: Settings
          Expanded(
            flex: 2,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionTitle("Différenciation"),
                DropdownButtonFormField<DifferentiationMode>(
                  initialValue: config.mode,
                  decoration: const InputDecoration(labelText: "Mode"),
                  items: DifferentiationMode.values.map((m) {
                    return DropdownMenuItem(
                      value: m,
                      child: Text(_modeLabel(m)),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      styleProvider.currentConfig = config.copyWith(mode: v);
                    }
                  },
                ),
                if (config.mode == DifferentiationMode.split) ...[
                  const SizedBox(height: 16),
                  Text("Touche de séparation: ${config.splitKey}"),
                  Slider(
                    value: config.splitKey.toDouble(),
                    min: 0,
                    max: 87,
                    divisions: 87,
                    label: config.splitKey.toString(),
                    onChanged: (v) {
                      styleProvider.currentConfig = config.copyWith(splitKey: v.toInt());
                    },
                  ),
                ],
                const SizedBox(height: 24),
                _sectionTitle("Couleurs de base"),
                _colorTile(
                  context,
                  config.mode == DifferentiationMode.blackWhite ? "Touches Blanches" : "Primaire (Gauche)",
                  config.colorA,
                  (c) => styleProvider.currentConfig = config.copyWith(colorA: c),
                ),
                if (config.mode != DifferentiationMode.none)
                  _colorTile(
                    context,
                    config.mode == DifferentiationMode.blackWhite ? "Touches Noires" : "Secondaire (Droite)",
                    config.colorB,
                    (c) => styleProvider.currentConfig = config.copyWith(colorB: c),
                  ),
                const SizedBox(height: 24),
                _sectionTitle("Texture (Gradient)"),
                SwitchListTile(
                  title: const Text("Activer le gradient global"),
                  subtitle: const Text("Applique un effet transparent sur un fond dégradé"),
                  value: config.useGradient,
                  onChanged: (v) {
                    styleProvider.currentConfig = config.copyWith(useGradient: v);
                  },
                ),
                if (config.useGradient) ...[
                  Text("Angle: ${config.gradientAngle.toInt()}°"),
                  Slider(
                    value: config.gradientAngle,
                    min: 0,
                    max: 360,
                    divisions: 36,
                    label: "${config.gradientAngle.toInt()}°",
                    onChanged: (v) {
                      styleProvider.currentConfig = config.copyWith(gradientAngle: v);
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text("Couleurs du dégradé:"),
                  Row(
                    children: [
                      ...config.gradientColors.asMap().entries.map((entry) {
                        int idx = entry.key;
                        Color c = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: _colorBubble(context, c, (newC) {
                            List<Color> newList = List.from(config.gradientColors);
                            newList[idx] = newC;
                            styleProvider.currentConfig = config.copyWith(gradientColors: newList);
                          }),
                        );
                      }),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          styleProvider.currentConfig = config.copyWith(
                            gradientColors: [...config.gradientColors, Colors.white],
                          );
                        },
                      ),
                      if (config.gradientColors.length > 2)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            styleProvider.currentConfig = config.copyWith(
                              gradientColors: List.from(config.gradientColors)..removeLast(),
                            );
                          },
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const VerticalDivider(),
          // Right: Saved Styles
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _sectionTitle("Styles Enregistrés"),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: styleProvider.savedConfigs.length,
                    itemBuilder: (context, index) {
                      final s = styleProvider.savedConfigs[index];
                      return ListTile(
                        title: Text(s.name),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => styleProvider.deleteConfig(s),
                        ),
                        onTap: () => styleProvider.applyConfig(s),
                        selected: config.name == s.name,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _modeLabel(DifferentiationMode mode) {
    switch (mode) {
      case DifferentiationMode.none:
        return "Aucune";
      case DifferentiationMode.blackWhite:
        return "Touches Noires / Blanches";
      case DifferentiationMode.split:
        return "Séparation Gauche / Droite";
    }
  }

  Widget _colorTile(BuildContext context, String label, Color color, Function(Color) onColorChanged) {
    return ListTile(
      title: Text(label),
      trailing: _colorBubble(context, color, onColorChanged),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _colorBubble(BuildContext context, Color color, Function(Color) onColorChanged) {
    return GestureDetector(
      onTap: () => _pickColor(context, color, onColorChanged),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey),
        ),
      ),
    );
  }

  void _pickColor(BuildContext context, Color initialColor, Function(Color) onColorChanged) {
    Color pickedColor = initialColor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Choisir une couleur"),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: initialColor,
            onColorChanged: (c) => pickedColor = c,
            enableAlpha: false,
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () {
              onColorChanged(pickedColor);
              Navigator.pop(context);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showSaveDialog(BuildContext context, StyleProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enregistrer le style"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Nom du style"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.saveCurrentConfig(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }
}
