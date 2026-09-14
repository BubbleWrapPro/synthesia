import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../providers/style_provider.dart';
import '../providers/session_provider.dart';
import '../models/style_config.dart';
import '../l10n.dart';

class CustomizationPage extends StatelessWidget {
  const CustomizationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final styleProvider = Provider.of<StyleProvider>(context);
    final sessionProvider = Provider.of<SessionProvider>(context);
    final config = styleProvider.currentConfig;

    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'customization_title')),
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
                _sectionTitle(t(context, 'differentiation')),
                DropdownButtonFormField<DifferentiationMode>(
                  initialValue: config.mode,
                  decoration: InputDecoration(labelText: t(context, 'mode')),
                  items: DifferentiationMode.values.map((m) {
                    return DropdownMenuItem(
                      value: m,
                      child: Text(_modeLabel(context, m)),
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
                  Text(t(context, 'split_key', {'key': config.splitKey.toString()})),
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
                if (config.mode == DifferentiationMode.byTrack) ...[
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(t(context, 'darken_black_keys')),
                    subtitle: Text(t(context, 'darken_black_keys_sub')),
                    value: config.darkenBlackKeysByTrack,
                    onChanged: (v) {
                      styleProvider.currentConfig = config.copyWith(darkenBlackKeysByTrack: v);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),
                  _sectionTitle(t(context, 'tracks')),
                  ...sessionProvider.availableTracks.map((tId) {
                    return _colorTile(
                      context,
                      t(context, 'track_label', {'id': tId.toString()}),
                      config.trackColors[tId] ?? config.colorA,
                      (c) {
                        final newMap = Map<int, Color>.from(config.trackColors);
                        newMap[tId] = c;
                        styleProvider.currentConfig = config.copyWith(trackColors: newMap);
                      },
                    );
                  }),
                ],
                if (config.mode == DifferentiationMode.gradient) ...[
                  const SizedBox(height: 24),
                  _sectionTitle(t(context, 'texture_gradient')),
                  Text(t(context, 'angle', {'angle': config.gradientAngle.toInt().toString()})),
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
                  Text(t(context, 'gradient_colors')),
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
                if (config.mode != DifferentiationMode.byTrack && config.mode != DifferentiationMode.gradient) ...[
                  const SizedBox(height: 24),
                  _sectionTitle(t(context, 'base_colors')),
                  _colorTile(
                    context,
                    config.mode == DifferentiationMode.blackWhite ? t(context, 'white_keys') : t(context, 'primary_left'),
                    config.colorA,
                    (c) => styleProvider.currentConfig = config.copyWith(colorA: c),
                  ),
                  if (config.mode != DifferentiationMode.none)
                    _colorTile(
                      context,
                      config.mode == DifferentiationMode.blackWhite ? t(context, 'black_keys') : t(context, 'secondary_right'),
                      config.colorB,
                      (c) => styleProvider.currentConfig = config.copyWith(colorB: c),
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
                  child: _sectionTitle(t(context, 'saved_styles')),
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

  String _modeLabel(BuildContext context, DifferentiationMode mode) {
    return switch (mode) {
      DifferentiationMode.none => t(context, 'mode_none'),
      DifferentiationMode.blackWhite => t(context, 'mode_black_white'),
      DifferentiationMode.split => t(context, 'mode_split'),
      DifferentiationMode.byTrack => t(context, 'mode_by_track'),
      DifferentiationMode.gradient => t(context, 'mode_gradient')
    };
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
        title: Text(t(context, 'choose_color')),
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
            child: Text(t(context, 'cancel')),
          ),
          TextButton(
            onPressed: () {
              onColorChanged(pickedColor);
              Navigator.pop(context);
            },
            child: Text(t(context, 'ok')),
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
        title: Text(t(context, 'save_style')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: t(context, 'style_name')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t(context, 'cancel')),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.saveCurrentConfig(controller.text);
                Navigator.pop(context);
              }
            },
            child: Text(t(context, 'save')),
          ),
        ],
      ),
    );
  }
}
