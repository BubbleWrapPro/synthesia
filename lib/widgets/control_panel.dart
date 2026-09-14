import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../pages/customization_page.dart';
import '../l10n.dart';

class ControlPanel extends StatelessWidget {
  const ControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SessionProvider>(context);
    final isEditMode = provider.currentMode == AppMode.edit;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (isEditMode) ...[
                  // 1. MENU FICHIER
                  PopupMenuButton<String>(
                    tooltip: t(context, 'file'),
                    icon: const Icon(Icons.file_copy, color: Colors.orange),
                    onSelected: (val) {
                      if (val == 'save') provider.saveToFile();
                      if (val == 'load') provider.importFile(context: context);
                      if (val == 'midi') provider.initMidi();
                      if (val == 'sf2') provider.pickAndLoadSoundFont(context: context);
                      if (val == 'built_in') _showBuiltInSoundFontsDialog(context, provider);
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'save', child: Text(t(context, 'save'))),
                      PopupMenuItem(value: 'load', child: Text(t(context, 'load'))),
                      const PopupMenuDivider(),
                      PopupMenuItem(value: 'sf2', child: Text(t(context, 'soundfont'))),
                      PopupMenuItem(value: 'built_in', child: Text(t(context, 'built_in'))),
                      PopupMenuItem(value: 'midi', child: Text(t(context, 'midi_init'))),
                      const PopupMenuDivider(),
                    ],
                  ),

                  const VerticalDivider(width: 10),

                  // 2. MENU ÉDITION
                  PopupMenuButton<String>(
                    tooltip: t(context, 'edition'),
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onSelected: (val) {
                      if (val == 'silence') _dialogSilence(context, provider);
                      if (val == 'rm_silence') _dialogRemoveSilence(context, provider);
                      if (val == 'del_note') provider.deleteLastNote(context);
                      if (val == 'chord') provider.toggleChordMode();
                      if (val == 'clear') provider.clearSession();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'chord',
                        child: Row(
                          children: [
                            Text(t(context, 'chord_mode')),
                            const Spacer(),
                            Switch(
                              value: provider.isChordMode,
                              onChanged: (v) => provider.toggleChordMode(),
                              activeThumbColor: Colors.green,
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(value: 'silence', child: Text(t(context, 'add_silence'))),
                      PopupMenuItem(value: 'rm_silence', child: Text(t(context, 'rm_silence'))),
                      PopupMenuItem(value: 'del_note', child: Text(t(context, 'del_note'))),
                      PopupMenuItem(value: 'clear', child: Text(t(context, 'clear_all'), style: const TextStyle(color: Colors.red))),
                    ],
                  ),

                  const VerticalDivider(width: 10),

                  // 3. PISTE (Gardé visible car central)
                  _actionGroup(t(context, 'track'), [
                    DropdownButton<int>(
                      value: provider.currentTrackId,
                      underline: Container(),
                      items: List.generate(10, (index) => DropdownMenuItem(
                        value: index,
                        child: Text("T$index", style: const TextStyle(fontWeight: FontWeight.bold)),
                      )),
                      onChanged: (v) => provider.setCurrentTrackId(v ?? 0),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(t(context, 'all_tracks'), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                        SizedBox(
                          height: 20, width: 20,
                          child: Checkbox(
                            value: provider.showAllTracksInEdit,
                            onChanged: (v) => provider.setShowAllTracksInEdit(v ?? false),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text("(V)", style: TextStyle(fontSize: 8, color: Colors.grey)),
                      ],
                    ),
                  ]),

                  const VerticalDivider(width: 10),

                  // 4. LECTURE & BPM
                  _actionGroup(t(context, 'playback'), [
                    SizedBox(
                      width: 45,
                      child: TextField(
                        decoration: const InputDecoration(labelText: "BPM", border: InputBorder.none),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        controller: TextEditingController(text: provider.bpm.toString()),
                        keyboardType: TextInputType.number,
                        onSubmitted: (v) => provider.setBpm(int.tryParse(v) ?? 60),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: const Icon(Icons.play_arrow, size: 20),
                      label: Text(t(context, 'play')),
                      onPressed: () => provider.playMusic(MediaQuery.of(context).size.height),
                    ),
                  ]),

                  const VerticalDivider(width: 10),

                  // 5. NAVIGATION (Compactée)
                  _actionGroup("", [
                    IconButton(
                      icon: const Icon(Icons.fast_rewind, color: Colors.blue),
                      onPressed: () {
                        double screenHeight = MediaQuery.of(context).size.height;
                        provider.seek(-(screenHeight / 8.0), screenHeight);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.fast_forward, color: Colors.blue),
                      onPressed: () {
                        double screenHeight = MediaQuery.of(context).size.height;
                        provider.seek(screenHeight / 8.0, screenHeight);
                      },
                    ),
                  ]),
                ] else ...[
                  // PLAY MODE CONTROLS
                  _actionGroup(t(context, 'playback'), [
                    _btn(t(context, 'edition'), () => provider.setMode(AppMode.edit), Colors.purple),
                    const VerticalDivider(width: 10),
                    IconButton(icon: const Icon(Icons.replay, color: Colors.orange), onPressed: () => provider.restartMusic(MediaQuery.of(context).size.height)),
                    if (provider.isPlaying && !provider.isPaused)
                      IconButton(icon: const Icon(Icons.pause, color: Colors.redAccent), onPressed: () => provider.pauseMusic())
                    else
                      IconButton(icon: const Icon(Icons.play_arrow, color: Colors.green), onPressed: () => provider.resumeMusic(MediaQuery.of(context).size.height)),
                    IconButton(
                      icon: const Icon(Icons.history, color: Colors.blue),
                      onPressed: () {
                        double screenHeight = MediaQuery.of(context).size.height;
                        double pixelsPerSecond = (screenHeight / 8.0) * (provider.bpm / 60.0);
                        provider.seek(-5 * pixelsPerSecond, screenHeight);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.update, color: Colors.blue),
                      onPressed: () {
                        double screenHeight = MediaQuery.of(context).size.height;
                        double pixelsPerSecond = (screenHeight / 8.0) * (provider.bpm / 60.0);
                        provider.seek(5 * pixelsPerSecond, screenHeight);
                      },
                    ),
                  ]),
                  const VerticalDivider(width: 10),
                  // Pistes à jouer
                  _actionGroup(t(context, 'tracks'),
                    provider.availableTracks.map((tId) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("T$tId", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                          SizedBox(
                            height: 24, width: 24,
                            child: Checkbox(
                              value: provider.activeTracks.contains(tId),
                              onChanged: (_) => provider.toggleTrack(tId),
                            ),
                          ),
                        ],
                      ),
                    )).toList()
                  ),
                ],

                const VerticalDivider(width: 10),

                // 6. SYSTÈME & STYLE
                IconButton(
                  tooltip: t(context, 'shortcuts'),
                  icon: const Icon(Icons.help_outline, color: Colors.blueGrey),
                  onPressed: () => _showShortcutsDialog(context),
                ),

                PopupMenuButton<String>(
                  tooltip: t(context, 'settings_style'),
                  icon: const Icon(Icons.settings, color: Colors.grey),
                  onSelected: (val) {
                    if (val == 'style') Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomizationPage()));
                    if (val == 'panic') provider.panic();
                    if (val == 'auto') provider.setAutoSilence(!provider.autoSilence);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'style',
                      child: Row(children: [const Icon(Icons.palette, size: 18), const SizedBox(width: 8), Text(t(context, 'appearance'))]),
                    ),
                    if (isEditMode)
                      PopupMenuItem(
                        value: 'auto',
                        child: Row(
                          children: [
                            Text(t(context, 'auto_silence')),
                            const Spacer(),
                            Checkbox(value: provider.autoSilence, onChanged: (v) => provider.setAutoSilence(v ?? false)),
                          ],
                        ),
                      ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'panic',
                      child: Row(children: [const Icon(Icons.warning, color: Colors.red, size: 18), const SizedBox(width: 8), Text(t(context, 'panic'), style: const TextStyle(color: Colors.red))]),
                    ),
                  ],
                ),

                // Petit rappel du fichier / soundfont
                if (isEditMode)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (provider.currentFileName.isNotEmpty)
                            Text(provider.currentFileName, style: const TextStyle(fontSize: 9, fontStyle: FontStyle.italic)),
                          Text(provider.currentSoundFontName, style: const TextStyle(fontSize: 8, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Progress Bar
        if (provider.isPlaying)
          LinearProgressIndicator(
            value: provider.animationScrollY,
            backgroundColor: Colors.grey[300],
            color: Colors.blue,
            minHeight: 4,
          ),
      ],
    );
  }

  Widget _actionGroup(String title, List<Widget> children) {
    return Row(children: children.map((c) => Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: c)).toList());
  }

  Widget _btn(String label, VoidCallback onTap, Color color) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  void _dialogSilence(BuildContext context, SessionProvider prov) {
    final controller = TextEditingController(text: "1");
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text(t(context, 'add_silence_title')),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: t(context, 'length')),
        keyboardType: TextInputType.number,
      ),
      actions: [
        TextButton(
          onPressed: () {
            int? val = int.tryParse(controller.text);
            if (val != null && val >= 1 && val <= 10) {
              prov.addSilence(val, MediaQuery.of(context).size.height);
              Navigator.pop(context);
            }
          },
          child: Text(t(context, 'add')),
        )
      ],
    ));
  }

  void _showBuiltInSoundFontsDialog(BuildContext context, SessionProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.library_music, color: Colors.orange),
            const SizedBox(width: 10),
            Text(t(context, 'built_in')),
          ],
        ),
        content: SizedBox(
          width: 400,
          height: 450,
          child: ListView.builder(
            itemCount: SessionProvider.builtInSoundFonts.length,
            itemBuilder: (context, index) {
              final sf = SessionProvider.builtInSoundFonts[index];
              final isSelected = provider.currentSoundFontName == sf['name'];
              return ListTile(
                title: Text(sf['name']!, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                subtitle: Text(sf['path']!, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  Navigator.pop(context);
                  provider.loadBuiltInSoundFont(sf['path']!, sf['name']!, context: context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t(context, 'close')),
          ),
        ],
      ),
    );
  }

  void _dialogRemoveSilence(BuildContext context, SessionProvider prov) {
    if (prov.session.isEmpty || !prov.session.last.isSilence) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t(context, 'error_no_silence'))));
      return;
    }

    int maxLen = 0;
    for (int i = prov.session.length - 1; i >= 0; i--) {
      if (prov.session[i].isSilence) {
        maxLen++;
      } else {
        break;
      }
    }

    final controller = TextEditingController(text: "1");
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text(t(context, 'remove_silence_title')),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: t(context, 'remove_silence_label', {'max': maxLen.toString()})),
        keyboardType: TextInputType.number,
      ),
      actions: [
        TextButton(
          onPressed: () {
            int? val = int.tryParse(controller.text);
            if (val != null && val >= 1 && val <= maxLen) {
              prov.removeSilence(val, MediaQuery.of(context).size.height);
              Navigator.pop(context);
            }
          },
          child: Text(t(context, 'remove')),
        )
      ],
    ));
  }

  void _showShortcutsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.keyboard, color: Colors.blue),
            const SizedBox(width: 10),
            Text(t(context, 'shortcuts')),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _shortcutGroup(t(context, 'file'), [
                  _shortcutItem(t(context, 'save'), "Ctrl + S"),
                  _shortcutItem(t(context, 'load'), "Ctrl + O"),
                  _shortcutItem(t(context, 'soundfont'), "Ctrl + F"),
                  _shortcutItem(t(context, 'midi_init'), "Ctrl + M"),
                ]),
                const Divider(),
                _shortcutGroup(t(context, 'edition'), [
                  _shortcutItem(t(context, 'chord_mode'), "A"),
                  _shortcutItem(t(context, 'add_silence'), "Espace"),
                  _shortcutItem(t(context, 'rm_silence'), "Retour Arrière"),
                  _shortcutItem(t(context, 'del_note'), "Suppr"),
                  _shortcutItem(t(context, 'clear_all'), "Ctrl + Suppr"),
                  _shortcutItem(t(context, 'all_tracks'), "V"),
                ]),
                const Divider(),
                _shortcutGroup(t(context, 'playback'), [
                  _shortcutItem(t(context, 'play'), "P"),
                  _shortcutItem(t(context, 'appearance'), "T"),
                  _shortcutItem(t(context, 'auto_silence'), "U"),
                  _shortcutItem(t(context, 'panic'), "Echap"),
                ]),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t(context, 'close')),
          ),
        ],
      ),
    );
  }

  Widget _shortcutGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        ),
        ...children,
      ],
    );
  }

  Widget _shortcutItem(String label, String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: Text(
              key,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
