import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';

class ControlPanel extends StatelessWidget {
  const ControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SessionProvider>(context);

    // Using LayoutBuilder to ensure buttons fit or use a ScrollView
    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.all(4.0),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // 1. Actions File
          _actionGroup("Fichier", [
            _btn("Effacer", () => provider.clearSession(), Colors.redAccent),
            _btn("Sauvegarder (S)", () => provider.saveToFile(), Colors.orange),
            _btn("Importer (O)", () => provider.importFile(), Colors.orange),
          ]),

          const VerticalDivider(width: 20),

          // 2. Actions Note/Silence
          _actionGroup("Édition", [
            // Toggle Accord
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text("Accord (A)", style: TextStyle(fontSize: 10)),
              Switch(
                value: provider.isChordMode,
                onChanged: (v) => provider.toggleChordMode(),
                activeThumbColor: Colors.green,
                inactiveThumbColor: Colors.grey,
              )
            ]),
            const SizedBox(width: 10),

            // Hauteur Defaut
            SizedBox(
              width: 50,
              child: TextField(
                decoration: const InputDecoration(labelText: "H (def)", counterText: ""),
                controller: TextEditingController(text: provider.defaultHeight.toString()),
                keyboardType: TextInputType.number,
                onSubmitted: (v) => provider.setDefaultHeight(double.tryParse(v) ?? 1.0),
              ),
            ),

            _btn("Silence (espace)", () => _dialogSilence(context, provider), Colors.grey),
            _btn("Sup. Silence (retour)", () => _dialogRemoveSilence(context, provider), Colors.grey),
            _btn("Effacer Note (del)", () => provider.deleteLastNote(context), Colors.grey),
          ]),

          const VerticalDivider(width: 20),

          // 3. Playback
          _actionGroup("Lecture", [
            SizedBox(
              width: 40,
              child: TextField(
                decoration: const InputDecoration(labelText: "BPM"),
                controller: TextEditingController(text: provider.bpm.toString()),
                keyboardType: TextInputType.number,
                onSubmitted: (v) => provider.setBpm(int.tryParse(v) ?? 60),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              icon: const Icon(Icons.play_arrow),
              label: const Text("JOUER (P)"),
              onPressed: () => provider.playMusic(MediaQuery.of(context).size.height),
            ),
          ]),

          const VerticalDivider(width: 20),

          // 4. MIDI Options (AJOUTÉ ICI)
          _actionGroup("Midi", [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Auto Silence", style: TextStyle(fontSize: 10)),
                // La taille par défaut de la Checkbox peut être grande, on peut utiliser Transform.scale pour ajuster si besoin
                Checkbox(
                  value: provider.autoSilence,
                  onChanged: (v) => provider.setAutoSilence(v ?? false),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ]),
        ],
      ),
    );
  }

  Widget _actionGroup(String title, List<Widget> children) {
    return Row(children: children.map((c) => Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: c)).toList());
  }

  Widget _btn(String label, VoidCallback onTap, Color color) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 10)),
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
              prov.addSilence(val);
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
              prov.removeSilence(val);
              Navigator.pop(context);
            }
          },
          child: const Text("Supprimer"),
        )
      ],
    ));
  }
}