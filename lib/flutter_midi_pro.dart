import 'package:flutter/services.dart';
import 'package:flutter_midi_pro/flutter_midi_pro_platform_interface.dart';

/// The FlutterMidiPro class provides functions for writing to and loading soundfont
/// files, as well as playing and stopping MIDI notes.
class MidiPro {
  /// This function loads an instrument in a soundfont file from the given path using the
  /// FlutterMidiProPlatform.
  /// Args:
  ///  sf2Path (String): The path to the soundfont file to be loaded.
  /// instrumentIndex (int): The index of the instrument to be loaded. Defaults to 0.
  Future<Object?> loadInstrument({required String sf2Path, int instrumentIndex = 0}) async {
    try {
      final sf2Data = await rootBundle.load(sf2Path).then((value) => value.buffer.asUint8List());
      return FlutterMidiProPlatform.instance
          .loadInstrument(sf2Data: sf2Data, instrumentIndex: instrumentIndex);
    } catch (e) {
      throw 'error loading instrument: $e';
    }
  }

  /// This function plays a MIDI note with a given MIDI value and velocity using the
  /// FlutterMidiProPlatform.
  ///
  /// Args:
  ///   midi (int): The MIDI note number to be played. MIDI note numbers range from
  /// 0 to 127, where 60 is middle C.
  ///   velocity (int): Velocity is a parameter in MIDI (Musical Instrument Digital
  /// Interface) that determines the volume or intensity of a note being played. It
  /// is measured on a scale of 0 to 127, with 0 being the softest and 127 being the
  /// loudest. In the code snippet provided, the. Defaults to 64 (medium loudness).
  Future<Object?> playMidiNote({
    required int midi,
    int velocity = 64,
  }) async {
    try {
      return FlutterMidiProPlatform.instance.playMidiNote(midi: midi, velocity: velocity);
    } catch (e) {
      throw 'error playing midi note: $e';
    }
  }

  /// This function stops a MIDI note with a given MIDI number and velocity.
  ///
  /// Args:
  ///   midi (int): The MIDI note number to stop playing. MIDI note numbers range from
  /// 0 to 127, with middle C being 60.
  ///   velocity (int): Velocity is a parameter in MIDI (Musical Instrument Digital
  /// Interface) that determines the strength or loudness of a note. It is measured on
  /// a scale of 0 to 127, with 0 being the softest and 127 being the loudest. In the
  /// code above, the default value. Defaults to 127 (the loudest).
  Future<Object?> stopMidiNote({
    required int midi,
    int velocity = 127,
  }) async {
    try {
      return FlutterMidiProPlatform.instance.stopMidiNote(midi: midi, velocity: velocity);
    } catch (e) {
      throw 'error stopping midi note: $e';
    }
  }

  /// This function disposes of the FlutterMidiProPlatform.
  /// This function should be called when the FlutterMidiPro object is no longer needed.
  /// It is important to call this function to free up resources and avoid memory leaks.
  Future<Object?> dispose() async {
    try {
      return FlutterMidiProPlatform.instance.dispose();
    } catch (e) {
      throw 'error disposing: $e';
    }
  }
}
