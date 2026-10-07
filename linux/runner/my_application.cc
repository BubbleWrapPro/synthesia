#include "my_application.h"

#include <climits>
#include <fluidsynth.h>
#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  fluid_settings_t* fluid_settings;
  fluid_synth_t* fluid_synth;
  fluid_audio_driver_t* fluid_audio_driver;
  int current_soundfont_id;
  FlMethodChannel* midi_pro_channel;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static void respond_success(FlMethodCall* call, FlValue* result = nullptr) {
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond_success(call, result, &error)) {
    g_warning("Failed to respond to MIDI method call: %s", error->message);
  }
}

static void respond_error(FlMethodCall* call, const gchar* code,
                          const gchar* message) {
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond_error(call, code, message, nullptr, &error)) {
    g_warning("Failed to respond to MIDI method call: %s", error->message);
  }
}

static bool get_int_argument(FlValue* args, const gchar* name, int* value) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return false;
  }
  FlValue* argument = fl_value_lookup_string(args, name);
  if (argument == nullptr || fl_value_get_type(argument) != FL_VALUE_TYPE_INT) {
    return false;
  }
  const int64_t raw_value = fl_value_get_int(argument);
  if (raw_value < INT_MIN || raw_value > INT_MAX) {
    return false;
  }
  *value = static_cast<int>(raw_value);
  return true;
}

static bool get_optional_int_argument(FlValue* args, const gchar* name,
                                      int fallback, int* value) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return false;
  }
  if (fl_value_lookup_string(args, name) == nullptr) {
    *value = fallback;
    return true;
  }
  return get_int_argument(args, name, value);
}

static const gchar* get_string_argument(FlValue* args, const gchar* name) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return nullptr;
  }
  FlValue* argument = fl_value_lookup_string(args, name);
  if (argument == nullptr || fl_value_get_type(argument) != FL_VALUE_TYPE_STRING) {
    return nullptr;
  }
  return fl_value_get_string(argument);
}

static void clear_fluid_synth(MyApplication* self) {
  if (self->fluid_audio_driver != nullptr) {
    delete_fluid_audio_driver(self->fluid_audio_driver);
    self->fluid_audio_driver = nullptr;
  }
  if (self->fluid_synth != nullptr) {
    delete_fluid_synth(self->fluid_synth);
    self->fluid_synth = nullptr;
  }
  if (self->fluid_settings != nullptr) {
    delete_fluid_settings(self->fluid_settings);
    self->fluid_settings = nullptr;
  }
  self->current_soundfont_id = -1;
}

static bool initialize_fluid_synth(MyApplication* self, int sample_rate,
                                   int buffer_size, int polyphony,
                                   gchar** error_message) {
  if (sample_rate < 8000 || sample_rate > 96000 || buffer_size < 1 ||
      buffer_size > 8192 || polyphony < 1) {
    *error_message = g_strdup("Invalid FluidSynth initialization settings");
    return false;
  }

  fluid_settings_t* settings = new_fluid_settings();
  if (settings == nullptr) {
    *error_message = g_strdup("Could not create FluidSynth settings");
    return false;
  }
  if (fluid_settings_setnum(settings, "synth.sample-rate", sample_rate) !=
          FLUID_OK ||
      fluid_settings_setint(settings, "audio.period-size", buffer_size) !=
          FLUID_OK ||
      fluid_settings_setint(settings, "synth.polyphony", polyphony) != FLUID_OK) {
    delete_fluid_settings(settings);
    *error_message = g_strdup("Could not configure FluidSynth settings");
    return false;
  }

  fluid_synth_t* synth = new_fluid_synth(settings);
  if (synth == nullptr) {
    delete_fluid_settings(settings);
    *error_message = g_strdup("Could not create FluidSynth synthesizer");
    return false;
  }

  // Leave the audio driver unset so FluidSynth can use the Linux system's
  // configured backend (for example, PulseAudio, PipeWire, or ALSA).
  fluid_audio_driver_t* audio_driver = new_fluid_audio_driver(settings, synth);
  if (audio_driver == nullptr) {
    delete_fluid_synth(synth);
    delete_fluid_settings(settings);
    *error_message = g_strdup("Could not open a FluidSynth audio output");
    return false;
  }

  self->fluid_settings = settings;
  self->fluid_synth = synth;
  self->fluid_audio_driver = audio_driver;
  self->current_soundfont_id = -1;
  return true;
}

static void midi_pro_method_call_cb(FlMethodChannel* channel,
                                    FlMethodCall* method_call,
                                    gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (g_strcmp0(method, "init") == 0) {
    if (self->fluid_synth != nullptr) {
      respond_success(method_call);
      return;
    }
    int sample_rate;
    int buffer_size;
    int polyphony;
    if (!get_optional_int_argument(args, "sampleRate", 44100, &sample_rate) ||
        !get_optional_int_argument(args, "bufferSize", 64, &buffer_size) ||
        !get_optional_int_argument(args, "polyphony", 64, &polyphony)) {
      respond_error(method_call, "Bad Arguments",
                    "Invalid FluidSynth initialization arguments");
      return;
    }
    gchar* error_message = nullptr;
    if (!initialize_fluid_synth(self, sample_rate, buffer_size, polyphony,
                                &error_message)) {
      respond_error(method_call, "FluidSynth Error", error_message);
      g_free(error_message);
      return;
    }
    respond_success(method_call);
    return;
  }

  if (g_strcmp0(method, "loadSoundfont") == 0 ||
      g_strcmp0(method, "loadSoundfontFile") == 0) {
    const gchar* path = get_string_argument(args, "path");
    int bank;
    int program;
    if (path == nullptr || path[0] == '\0' ||
        !get_optional_int_argument(args, "bank", 0, &bank) ||
        !get_optional_int_argument(args, "program", 0, &program) || bank < 0 ||
        bank > 16383 || program < 0 || program > 127) {
      respond_error(method_call, "Bad Arguments",
                    "Expected a SoundFont path and valid bank/program numbers");
      return;
    }
    if (self->fluid_synth == nullptr) {
      respond_error(method_call, "FluidSynth Error",
                    "FluidSynth is not initialized");
      return;
    }

    const int soundfont_id = fluid_synth_sfload(self->fluid_synth, path, 0);
    if (soundfont_id == FLUID_FAILED) {
      respond_error(method_call, "FluidSynth Error",
                    "FluidSynth could not load the selected SoundFont");
      return;
    }
    if (fluid_synth_program_select(self->fluid_synth, 0, soundfont_id, bank,
                                   program) != FLUID_OK) {
      fluid_synth_sfunload(self->fluid_synth, soundfont_id, 0);
      respond_error(method_call, "FluidSynth Error",
                    "The requested bank/program is not present in this SoundFont");
      return;
    }
    if (self->current_soundfont_id != -1 &&
        fluid_synth_sfunload(self->fluid_synth, self->current_soundfont_id, 0) !=
            FLUID_OK) {
      g_warning("Loaded the new SoundFont but could not unload the previous one");
    }
    self->current_soundfont_id = soundfont_id;
    g_autoptr(FlValue) result = fl_value_new_int(soundfont_id);
    respond_success(method_call, result);
    return;
  }

  if (g_strcmp0(method, "playNote") == 0 ||
      g_strcmp0(method, "stopNote") == 0) {
    int channel;
    int note;
    int soundfont_id;
    if (!get_int_argument(args, "channel", &channel) ||
        !get_int_argument(args, "key", &note) ||
        !get_int_argument(args, "sfId", &soundfont_id) || channel < 0 ||
        channel > 15 || note < 0 || note > 127) {
      respond_error(method_call, "Bad Arguments",
                    "Expected a valid channel, note, and SoundFont ID");
      return;
    }
    if (self->fluid_synth == nullptr ||
        soundfont_id != self->current_soundfont_id) {
      respond_error(method_call, "FluidSynth Error",
                    "The requested SoundFont is not loaded");
      return;
    }

    int status;
    if (g_strcmp0(method, "playNote") == 0) {
      int velocity;
      if (!get_int_argument(args, "velocity", &velocity) || velocity < 0 ||
          velocity > 127) {
        respond_error(method_call, "Bad Arguments",
                      "Expected a MIDI velocity between 0 and 127");
        return;
      }
      status = fluid_synth_noteon(self->fluid_synth, channel, note, velocity);
    } else {
      status = fluid_synth_noteoff(self->fluid_synth, channel, note);
    }
    if (status != FLUID_OK) {
      respond_error(method_call, "FluidSynth Error",
                    "FluidSynth could not process the note event");
      return;
    }
    respond_success(method_call);
    return;
  }

  if (g_strcmp0(method, "stopAllNotes") == 0 || g_strcmp0(method, "panic") == 0) {
    if (self->fluid_synth == nullptr) {
      respond_error(method_call, "FluidSynth Error",
                    "FluidSynth is not initialized");
      return;
    }
    for (int channel = 0; channel < 16; channel++) {
      if (fluid_synth_all_notes_off(self->fluid_synth, channel) != FLUID_OK) {
        respond_error(method_call, "FluidSynth Error",
                      "FluidSynth could not stop all notes");
        return;
      }
    }
    respond_success(method_call);
    return;
  }

  if (g_strcmp0(method, "dispose") == 0) {
    clear_fluid_synth(self);
    respond_success(method_call);
    return;
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond_not_implemented(method_call, &error)) {
    g_warning("Failed to reject an unsupported MIDI method call: %s",
              error->message);
  }
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView *view)
{
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "synthesia");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "synthesia");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  g_autoptr(FlStandardMethodCodec) method_codec =
      fl_standard_method_codec_new();
  self->midi_pro_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "flutter_midi_pro", FL_METHOD_CODEC(method_codec));
  fl_method_channel_set_method_call_handler(self->midi_pro_channel,
                                            midi_pro_method_call_cb, self,
                                            nullptr);

  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000 for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb), self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  if (self->midi_pro_channel != nullptr) {
    fl_method_channel_set_method_call_handler(self->midi_pro_channel, nullptr,
                                              nullptr, nullptr);
    g_clear_object(&self->midi_pro_channel);
  }
  clear_fluid_synth(self);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {
  self->fluid_settings = nullptr;
  self->fluid_synth = nullptr;
  self->fluid_audio_driver = nullptr;
  self->current_soundfont_id = -1;
  self->midi_pro_channel = nullptr;
}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
