import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How much larger than normal to draw all text. Applied on top of the
/// device's own text-size setting (see `main.dart`).
enum TextSizeOption {
  normal(1.0, 'Default'),
  large(1.15, 'Large'),
  larger(1.3, 'Larger'),
  largest(1.5, 'Largest');

  const TextSizeOption(this.scale, this.label);

  final double scale;
  final String label;
}

class AccessibilitySettings {
  const AccessibilitySettings({
    this.textSize = TextSizeOption.normal,
    this.reduceMotion = false,
    this.readAloud = false,
  });

  final TextSizeOption textSize;

  /// No shimmer or decorative animation. The device's own "reduce motion"
  /// setting is honoured as well (see `main.dart`).
  final bool reduceMotion;

  /// Citizens: tap anything once to hear it read out, again to use it.
  /// Off by default -- it changes how every tap behaves.
  final bool readAloud;

  AccessibilitySettings copyWith({
    TextSizeOption? textSize,
    bool? reduceMotion,
    bool? readAloud,
  }) =>
      AccessibilitySettings(
        textSize: textSize ?? this.textSize,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        readAloud: readAloud ?? this.readAloud,
      );
}

const _textSizeKey = 'ubuntuid_text_scale';
const _reduceMotionKey = 'ubuntuid_reduce_motion';
const _readAloudKey = 'ubuntuid_tap_to_hear';

/// Per-device accessibility preferences, saved like the theme choice.
class AccessibilityController extends Notifier<AccessibilitySettings> {
  @override
  AccessibilitySettings build() {
    _load();
    return const AccessibilitySettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AccessibilitySettings(
      textSize: TextSizeOption.values.where((o) => o.name == prefs.getString(_textSizeKey)).firstOrNull ??
          TextSizeOption.normal,
      reduceMotion: prefs.getBool(_reduceMotionKey) ?? false,
      readAloud: prefs.getBool(_readAloudKey) ?? false,
    );
  }

  Future<void> setTextSize(TextSizeOption option) async {
    state = state.copyWith(textSize: option);
    await (await SharedPreferences.getInstance()).setString(_textSizeKey, option.name);
  }

  Future<void> setReduceMotion(bool value) async {
    state = state.copyWith(reduceMotion: value);
    await (await SharedPreferences.getInstance()).setBool(_reduceMotionKey, value);
  }

  Future<void> setReadAloud(bool value) async {
    state = state.copyWith(readAloud: value);
    await (await SharedPreferences.getInstance()).setBool(_readAloudKey, value);
  }
}

final accessibilityControllerProvider =
    NotifierProvider<AccessibilityController, AccessibilitySettings>(AccessibilityController.new);
