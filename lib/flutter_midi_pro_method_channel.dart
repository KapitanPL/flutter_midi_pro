import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_midi_pro/flutter_midi_pro_platform_interface.dart';

/// An implementation of [FlutterMidiProPlatform] that uses method channels.
class MethodChannelFlutterMidiPro extends FlutterMidiProPlatform {
  static const MethodChannel _channel = MethodChannel('flutter_midi_pro');

  @override
  Future<int> loadSoundfont(String path, {bool? resetPresets}) async {
    final int sfId = await _channel.invokeMethod(
        'loadSoundfont', {'path': path, 'resetPresets': resetPresets});
    return sfId;
  }

  @override
  Future<void> selectInstrument(
      int sfId, int channel, int bank, int program) async {
    await _channel.invokeMethod('selectInstrument',
        {'sfId': sfId, 'channel': channel, 'bank': bank, 'program': program});
  }

  @override
  Future<Map<int, Map<int, String>>> listBanksAndPrograms(int sfId) async {
    final banksAndPrograms =
        await _channel.invokeMethod('listBanksAndPrograms', {'sfId': sfId});
    final Map<int, Map<int, String>> converted = {};
    for (final bank in (banksAndPrograms as Map).keys) {
      converted[bank] = {};
      for (final programN in (banksAndPrograms[bank] as Map).keys) {
        converted[bank]![programN] =
            ((banksAndPrograms[bank] as Map)[programN]) as String;
      }
    }
    return converted;
  }

  @override
  Future<void> playNote(int channel, int key, int velocity) async {
    await _channel.invokeMethod(
        'playNote', {'channel': channel, 'key': key, 'velocity': velocity});
  }

  @override
  Future<void> stopNote(int channel, int key) async {
    await _channel.invokeMethod('stopNote', {'channel': channel, 'key': key});
  }

  @override
  Future<void> unloadSoundfont(int sfId, {bool? resetPresets}) async {
    await _channel.invokeMethod(
        'unloadSoundfont', {'sfId': sfId, 'resetPresets': resetPresets});
  }

  @override
  Future<void> dispose() async {
    await _channel.invokeMethod('dispose');
  }
}
