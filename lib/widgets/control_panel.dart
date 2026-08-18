import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../pages/customization_page.dart';

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
                    tooltip: "Fichier",
                    icon: const Icon(Icons.file_copy, color: Colors.orange),
                    onSelected: (val) {
                      if (val == 'save') provider.saveToFile();
                      if (val == 'load') provider.importFile();
                      if (val == 'midi') provider.initMidi();
                      if (val == 'sf2') provider.pickAndLoadSoundFont();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'save', child: Text("Sauvegarder (Ctrl+S)")),
                      const PopupMenuItem(value: 'load', child: Text("Importer (Ctrl+O)")),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'sf2', child: Text("Charger SoundFont (Ctrl+F)")),
                      const PopupMenuItem(value: 'built_in', child: Text("SoundFonts Intégrés")),
                      const PopupMenuItem(value: 'midi', child: Text("Réinit MIDI (Ctrl+M)")),
                      const PopupMenuDivider(),
                    ],
                  ),

                  const VerticalDivider(width: 10),

                  // 2. MENU ÉDITION
                  PopupMenuButton<String>(
                    tooltip: "Édition",
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
                            const Text("Mode Accord (A)"),
                            const Spacer(),
                            Switch(
                              value: provider.isChordMode,
                              onChanged: (v) => provider.toggleChordMode(),
                              activeThumbColor: Colors.green,
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(value: 'silence', child: Text("Ajouter Silence (Espace)")),
                      const PopupMenuItem(value: 'rm_silence', child: Text("Suppr. Silence (Retour)")),
                      const PopupMenuItem(value: 'del_note', child: Text("Effacer Note (Del)")),
                      const PopupMenuItem(value: 'clear', child: Text("Tout Effacer", style: TextStyle(color: Colors.red))),
                    ],
                  ),

                  const VerticalDivider(width: 10),

                  // 3. PISTE (Gardé visible car central)
                  _actionGroup("Piste", [
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
                        const Text("Toutes", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
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
                  _actionGroup("Lecture", [
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
                      label: const Text("JOUER (P)"),
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
                  // PLAY MODE CONTROLS (Déjà assez compact, on garde l'essentiel)
                  _actionGroup("Playback", [
                    _btn("Édition", () => provider.setMode(AppMode.edit), Colors.purple),
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
                  // Pistes à jouer (Reste visible pour le mixage)
                  _actionGroup("Pistes", 
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

                // 6. SYSTÈME & STYLE (Regroupés)
                IconButton(
                  tooltip: "Raccourcis Clavier",
                  icon: const Icon(Icons.help_outline, color: Colors.blueGrey),
                  onPressed: () => _showShortcutsDialog(context),
                ),

                PopupMenuButton<String>(
                  tooltip: "Paramètres & Style",
                  icon: const Icon(Icons.settings, color: Colors.grey),
                  onSelected: (val) {
                    if (val == 'style') Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomizationPage()));
                    if (val == 'panic') provider.panic();
                    if (val == 'auto') provider.setAutoSilence(!provider.autoSilence);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'style',
                      child: Row(children: const [Icon(Icons.palette, size: 18), SizedBox(width: 8), Text("Apparence (T)")]),
                    ),
                    if (isEditMode)
                      PopupMenuItem(
                        value: 'auto',
                        child: Row(
                          children: [
                            const Text("Auto Silence (U)"),
                            const Spacer(),
                            Checkbox(value: provider.autoSilence, onChanged: (v) => provider.setAutoSilence(v ?? false)),
                          ],
                        ),
                      ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'panic',
                      child: Row(children: const [Icon(Icons.warning, color: Colors.red, size: 18), SizedBox(width: 8), Text("PANIC (Esc)", style: TextStyle(color: Colors.red))]),
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

  // Popup for adding Silence
  void _dialogSilence(BuildContext context, SessionProvider prov) {
    final controller = TextEditingController(text: "1");
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text("Ajouter un silence"),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(labelText: "Longueur (1-10)"),
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
          child: const Text("Ajouter"),
        )
      ],
    ));
  }

  // Popup for removing Silence
  void _dialogRemoveSilence(BuildContext context, SessionProvider prov) {
    if (prov.session.isEmpty || !prov.session.last.isSilence) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur: La dernière tuile n'est pas un silence.")));
      return;
    }

    // Calculate max silence length available at the end
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
      title: const Text("Supprimer Silence"),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: "Combien retirer ? (Max: $maxLen)"),
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
          child: const Text("Supprimer"),
        )
      ],
    ));
  }

  void _showShortcutsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.keyboard, color: Colors.blue),
            SizedBox(width: 10),
            Text("Raccourcis Clavier"),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _shortcutGroup("Fichier", [
                  _shortcutItem("Sauvegarder", "Ctrl + S"),
                  _shortcutItem("Importer", "Ctrl + O"),
                  _shortcutItem("Charger SoundFont", "Ctrl + F"),
                  _shortcutItem("Réinit MIDI", "Ctrl + M"),
                ]),
                const Divider(),
                _shortcutGroup("Édition", [
                  _shortcutItem("Mode Accord", "A"),
                  _shortcutItem("Ajouter Silence", "Espace"),
                  _shortcutItem("Supprimer Silence", "Retour Arrière"),
                  _shortcutItem("Effacer dernière Note", "Suppr"),
                  _shortcutItem("Tout Effacer", "Ctrl + Suppr"),
                  _shortcutItem("Afficher toutes les pistes", "V"),
                ]),
                const Divider(),
                _shortcutGroup("Lecture & Système", [
                  _shortcutItem("Mode Jouer / Stop", "P"),
                  _shortcutItem("Apparence", "T"),
                  _shortcutItem("Auto-silence", "U"),
                  _shortcutItem("PANIC (Silence complet)", "Echap"),
                ]),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
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