import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';

class ControlPanel extends StatelessWidget {
  const ControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SessionProvider>(context);

    return Container(
      color: Colors.grey[200],
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _btn("Effacer", () => provider.clearSession(), Colors.red),

          _btn("Sauvegarder", () => provider.saveToFile(), Colors.orange),

          _btn("Importer", () => provider.importFile(), Colors.orange),

          // Toggle Accord
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text("Accord"),
            Switch(
                value: provider.isChordMode,
                onChanged: (v) => provider.toggleChordMode()
            )
          ]),

          // Input: Hauteur Défaut
          _input(context, "Hauteur", provider.defaultHeight.toString(), (v) {
            double? d = double.tryParse(v);
            if(d != null) provider.setDefaultHeight(d);
          }),

          // Input: Silence
          _btn("Silence", () => _dialogSilence(context, provider), Colors.grey),

          // Input: BPM
          _input(context, "BPM", "60", (v) {
            int? b = int.tryParse(v);
            if(b != null) provider.setBpm(b);
          }),

          _btn("JOUER", () {
            // Pass screen height for animation calculations
            provider.playMusic(MediaQuery.of(context).size.height);
          }, Colors.green),
        ],
      ),
    );
  }

  Widget _btn(String label, VoidCallback onTap, Color color) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: color),
      onPressed: onTap,
      child: Text(label, style: TextStyle(fontSize: 12)),
    );
  }

  Widget _input(BuildContext context, String label, String init, Function(String) onSub) {
    return SizedBox(
      width: 60,
      child: TextField(
        decoration: InputDecoration(labelText: label),
        controller: TextEditingController(text: init),
        keyboardType: TextInputType.number,
        onSubmitted: onSub,
      ),
    );
  }

  void _dialogSilence(BuildContext context, SessionProvider prov) {
    // Show dialog to ask for X length (1-10)
    // Then call prov.addSilence(x)
  }
}