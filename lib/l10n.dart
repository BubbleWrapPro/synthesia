import 'package:flutter/widgets.dart';

class AppLocalizations {
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'file': 'File',
      'save': 'Save (Ctrl+S)',
      'load': 'Import (Ctrl+O)',
      'soundfont': 'Load SoundFont (Ctrl+F)',
      'built_in': 'Built-in SoundFonts',
      'midi_init': 'Reinit MIDI (Ctrl+M)',
      'edition': 'Edit',
      'chord_mode': 'Chord Mode (A)',
      'add_silence': 'Add Silence (Space)',
      'rm_silence': 'Remove Silence (Backspace)',
      'del_note': 'Delete Note (Del)',
      'clear_all': 'Clear All',
      'track': 'Track',
      'tracks': 'Tracks',
      'all_tracks': 'All',
      'playback': 'Playback',
      'play': 'PLAY (P)',
      'pause': 'Pause',
      'resume': 'Resume',
      'restart': 'Restart',
      'shortcuts': 'Keyboard Shortcuts',
      'settings_style': 'Settings & Style',
      'appearance': 'Appearance (T)',
      'auto_silence': 'Auto Silence (U)',
      'panic': 'PANIC (Esc)',
      'add_silence_title': 'Add a silence',
      'length': 'Length (1-10)',
      'add': 'Add',
      'close': 'Close',
      'remove_silence_title': 'Remove Silence',
      'remove_silence_label': 'How many to remove? (Max: {max})',
      'remove': 'Remove',
      'error_no_silence': 'Error: The last tile is not a silence.',
      'error_no_note': 'No note to delete.',
      'error_invalid_sf2': 'Please select a valid SoundFont (.sf2) file.',
      'soundfont_loaded': 'Built-in SoundFont loaded: {name}',
      'soundfont_error': 'Error loading {name}',
      'json_import_error': 'Error importing JSON file: {error}',
      'customization_title': 'Notes Customization',
      'differentiation': 'Differentiation',
      'mode': 'Mode',
      'mode_none': 'None',
      'mode_black_white': 'Black / White Keys',
      'mode_split': 'Left / Right Split',
      'mode_by_track': 'By Track',
      'mode_gradient': 'Global Gradient',
      'split_key': 'Split key: {key}',
      'darken_black_keys': 'Darken black keys',
      'darken_black_keys_sub': 'Apply a darker tint to black notes of each track',
      'track_label': 'Track {id}',
      'texture_gradient': 'Texture (Gradient)',
      'angle': 'Angle: {angle}°',
      'gradient_colors': 'Gradient colors:',
      'base_colors': 'Base colors',
      'white_keys': 'White Keys',
      'black_keys': 'Black Keys',
      'primary_left': 'Primary (Left)',
      'secondary_right': 'Secondary (Right)',
      'saved_styles': 'Saved Styles',
      'choose_color': 'Choose a color',
      'cancel': 'Cancel',
      'ok': 'OK',
      'save_style': 'Save Style',
      'style_name': 'Style Name',
      'edit_note': 'Edit Note',
      'duration_height': 'Duration (Height)',
      'color': 'Color:',
      'reset_color': 'Reset Color',
      'delete': 'Delete',
      'validate': 'Validate',
    },
    'fr': {
      'file': 'Fichier',
      'save': 'Sauvegarder (Ctrl+S)',
      'load': 'Importer (Ctrl+O)',
      'soundfont': 'Charger SoundFont (Ctrl+F)',
      'built_in': 'SoundFonts Intégrés',
      'midi_init': 'Réinit MIDI (Ctrl+M)',
      'edition': 'Édition',
      'chord_mode': 'Mode Accord (A)',
      'add_silence': 'Ajouter Silence (Espace)',
      'rm_silence': 'Suppr. Silence (Retour)',
      'del_note': 'Effacer Note (Del)',
      'clear_all': 'Tout Effacer',
      'track': 'Piste',
      'tracks': 'Pistes',
      'all_tracks': 'Toutes',
      'playback': 'Lecture',
      'play': 'JOUER (P)',
      'pause': 'Pause',
      'resume': 'Reprendre',
      'restart': 'Recommencer',
      'shortcuts': 'Raccourcis Clavier',
      'settings_style': 'Paramètres & Style',
      'appearance': 'Apparence (T)',
      'auto_silence': 'Auto Silence (U)',
      'panic': 'PANIC (Esc)',
      'add_silence_title': 'Ajouter un silence',
      'length': 'Longueur (1-10)',
      'add': 'Ajouter',
      'close': 'Fermer',
      'remove_silence_title': 'Supprimer Silence',
      'remove_silence_label': 'Combien retirer ? (Max: {max})',
      'remove': 'Supprimer',
      'error_no_silence': 'Erreur: La dernière tuile n\'est pas un silence.',
      'error_no_note': 'Aucune note à effacer.',
      'error_invalid_sf2': 'Veuillez sélectionner un fichier SoundFont (.sf2) valide.',
      'soundfont_loaded': 'SoundFont intégré chargé : {name}',
      'soundfont_error': 'Erreur lors du chargement de {name}',
      'json_import_error': 'Erreur lors de l\'import du fichier JSON : {error}',
      'customization_title': 'Personnalisation des Notes',
      'differentiation': 'Différenciation',
      'mode': 'Mode',
      'mode_none': 'Aucune',
      'mode_black_white': 'Touches Noires / Blanches',
      'mode_split': 'Séparation Gauche / Droite',
      'mode_by_track': 'Par Piste',
      'mode_gradient': 'Gradient Global',
      'split_key': 'Touche de séparation: {key}',
      'darken_black_keys': 'Assombrir les touches noires',
      'darken_black_keys_sub': 'Applique une teinte plus sombre aux notes noires de chaque piste',
      'track_label': 'Piste {id}',
      'texture_gradient': 'Texture (Gradient)',
      'angle': 'Angle: {angle}°',
      'gradient_colors': 'Couleurs du dégradé:',
      'base_colors': 'Couleurs de base',
      'white_keys': 'Touches Blanches',
      'black_keys': 'Touches Noires',
      'primary_left': 'Primaire (Gauche)',
      'secondary_right': 'Secondaire (Droite)',
      'saved_styles': 'Styles Enregistrés',
      'choose_color': 'Choisir une couleur',
      'cancel': 'Annuler',
      'ok': 'OK',
      'save_style': 'Enregistrer le style',
      'style_name': 'Nom du style',
      'edit_note': 'Modifier la note',
      'duration_height': 'Durée (Hauteur)',
      'color': 'Couleur:',
      'reset_color': 'Réinitialiser la couleur',
      'delete': 'Supprimer',
      'validate': 'Valider',
    },
  };

  static String get(BuildContext context, String key, [Map<String, String>? params]) {
    String lang = 'en';

    // 1. Try context localizations
    try {
      final locale = Localizations.localeOf(context).languageCode;
      if (_localizedValues.containsKey(locale)) {
        lang = locale;
      }
    } catch (_) {}

    // 2. Try platform dispatcher preferred locales (handles OS language preference list on Windows/Mac/Linux/Mobile)
    if (lang == 'en') {
      try {
        for (final locale in WidgetsBinding.instance.platformDispatcher.locales) {
          if (_localizedValues.containsKey(locale.languageCode)) {
            lang = locale.languageCode;
            break;
          }
        }
      } catch (_) {}
    }

    // 3. Try primary platform locale
    if (lang == 'en') {
      try {
        final platformLocale = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
        if (_localizedValues.containsKey(platformLocale)) {
          lang = platformLocale;
        }
      } catch (_) {}
    }

    String text = _localizedValues[lang]?[key] ?? _localizedValues['en']?[key] ?? key;

    if (params != null) {
      params.forEach((k, v) {
        text = text.replaceAll('{$k}', v);
      });
    }

    return text;
  }
}

String t(BuildContext context, String key, [Map<String, String>? params]) {
  return AppLocalizations.get(context, key, params);
}
