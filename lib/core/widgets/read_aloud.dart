import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../models/user_role.dart';
import '../../services/service_providers.dart';
import '../theme/accessibility_controller.dart';

/// Speaks text with the device's own voice (the browser's speech synthesis
/// on the web): nothing to record or host.
class ReadAloudController {
  final _tts = FlutterTts();
  bool _configured = false;

  Future<void> _configure() async {
    if (_configured) return;
    _configured = true;
    try {
      // A South African English voice when the device has one.
      await _tts.setLanguage(await _tts.isLanguageAvailable('en-ZA') == true ? 'en-ZA' : 'en-GB');
    } catch (_) {
      // Keep the device's default voice.
    }
  }

  Future<void> say(String text) async {
    await _configure();
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}

final readAloudControllerProvider = Provider<ReadAloudController>((ref) {
  final controller = ReadAloudController();
  ref.onDispose(controller.stop);
  return controller;
});

/// Tap to hear, for citizens who turned on Read aloud: the first tap on
/// anything -- text, a button, a field -- reads it out instead of using it;
/// tapping the same thing again uses it. Scrolling is unaffected.
///
/// What was tapped is found in the semantics tree screen readers use, so
/// every screen is covered without listing its text.
class CitizenReadAloud extends ConsumerWidget {
  const CitizenReadAloud({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCitizen = ref.watch(currentRoleProvider).value?.role == UserRole.citizen;
    final enabled = ref.watch(accessibilityControllerProvider).readAloud;
    if (!isCitizen || !enabled) return child;
    return _TapToHear(speaker: ref.read(readAloudControllerProvider), child: child);
  }
}

class _TapToHear extends StatefulWidget {
  const _TapToHear({required this.speaker, required this.child});

  final ReadAloudController speaker;
  final Widget child;

  @override
  State<_TapToHear> createState() => _TapToHearState();
}

class _TapToHearState extends State<_TapToHear> {
  late final SemanticsHandle _semantics;
  int? _lastNodeId;
  DateTime _lastAt = DateTime(0);

  @override
  void initState() {
    super.initState();
    // Native apps only build the semantics tree while something asks for it.
    _semantics = SemanticsBinding.instance.ensureSemantics();
  }

  @override
  void dispose() {
    _semantics.dispose();
    widget.speaker.stop();
    super.dispose();
  }

  /// Returns true when the tap was used to read something out, so the
  /// widget underneath must not act on it.
  bool _onTap(Offset position) {
    final node = _targetAt(position);
    if (node == null) return false;
    final now = DateTime.now();
    if (node.id == _lastNodeId && now.difference(_lastAt) < const Duration(seconds: 15)) {
      _lastNodeId = null; // Second tap: let it through, and read again next time.
      widget.speaker.stop();
      return false;
    }
    final text = _describe(node);
    if (text.isEmpty) return false;
    _lastNodeId = node.id;
    _lastAt = now;
    widget.speaker.say(text);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        _FirstTapRecognizer: GestureRecognizerFactoryWithHandlers<_FirstTapRecognizer>(
          () => _FirstTapRecognizer(),
          (recognizer) => recognizer.onTap = _onTap,
        ),
      },
      child: widget.child,
    );
  }
}

/// Joins the gesture arena for every tap. On release it either claims the
/// tap (it was read aloud, so the button underneath doesn't fire) or steps
/// aside. Any drag beyond the touch slop is left to scrolling.
class _FirstTapRecognizer extends OneSequenceGestureRecognizer {
  bool Function(Offset position)? onTap;
  Offset? _down;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (event.buttons != kPrimaryButton) return;
    _down = event.position;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent && (event.position - _down!).distance > kTouchSlop) {
      resolve(GestureDisposition.rejected);
      stopTrackingPointer(event.pointer);
    } else if (event is PointerUpEvent) {
      final claim = onTap?.call(event.position) ?? false;
      resolve(claim ? GestureDisposition.accepted : GestureDisposition.rejected);
      stopTrackingPointer(event.pointer);
    } else if (event is PointerCancelEvent) {
      resolve(GestureDisposition.rejected);
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'tap to hear';
}

/// The thing under [position]: the nearest tappable node (a button, card,
/// field) if there is one, otherwise the deepest node with text.
SemanticsNode? _targetAt(Offset position) {
  for (final view in RendererBinding.instance.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root == null) continue;
    // Semantics rects may be in physical pixels; match the pointer to them.
    final rootRect = MatrixUtils.transformRect(root.transform ?? Matrix4.identity(), root.rect);
    final logicalWidth = view.size.width;
    final scale = logicalWidth == 0 ? 1.0 : rootRect.width / logicalWidth;
    final path = <SemanticsNode>[];
    _hitPath(root, Matrix4.identity(), position * scale, path);
    if (path.isEmpty) continue;

    // Merged children are part of their parent.
    var deepest = path.length - 1;
    while (deepest > 0 && path[deepest].isMergedIntoParent) {
      deepest--;
    }
    for (var i = deepest; i >= 0; i--) {
      final data = path[i].getSemanticsData();
      if (data.hasAction(SemanticsAction.tap) || data.flagsCollection.isTextField) return path[i];
    }
    for (var i = deepest; i >= 0; i--) {
      if (_describe(path[i]).isNotEmpty) return path[i];
    }
  }
  return null;
}

/// Fills [path] with the nodes containing [point], outermost first; where
/// siblings overlap, the one painted last (on top) wins.
bool _hitPath(SemanticsNode node, Matrix4 parent, Offset point, List<SemanticsNode> path) {
  final data = node.getSemanticsData();
  if (data.flagsCollection.isHidden) return false;
  final transform = node.transform == null ? parent : parent.multiplied(node.transform!);
  if (!MatrixUtils.transformRect(transform, node.rect).contains(point)) return false;
  path.add(node);
  final children = <SemanticsNode>[];
  node.visitChildren((child) {
    children.add(child);
    return true;
  });
  for (final child in children.reversed) {
    if (_hitPath(child, transform, point, path)) break;
  }
  return true;
}

/// What to say for [node]: its text (and its children's, for a card whose
/// text sits in separate nodes), what kind of control it is, and how to use it.
String _describe(SemanticsNode node) {
  final data = node.getSemanticsData();
  final parts = <String>[];
  void add(String text) {
    final t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isNotEmpty && !parts.contains(t)) parts.add(t);
  }

  add(data.label);
  add(data.value);
  add(data.tooltip);
  if (!node.mergeAllDescendantsIntoThisNode) {
    void visit(SemanticsNode n) {
      final d = n.getSemanticsData();
      if (!d.flagsCollection.isHidden) {
        if (!n.isMergedIntoParent) {
          add(d.label);
          add(d.value);
        }
        n.visitChildren((c) {
          visit(c);
          return true;
        });
      }
    }

    node.visitChildren((c) {
      visit(c);
      return true;
    });
  }
  if (parts.isEmpty) return '';

  final flags = data.flagsCollection;
  final kind = flags.isTextField
      ? 'text field'
      : flags.isLink
          ? 'link'
          : flags.isButton
              ? 'button'
              : null;
  final actionable = data.hasAction(SemanticsAction.tap) || flags.isTextField;
  return [
    parts.join('. '),
    ?kind,
    if (actionable) 'Tap again to ${flags.isTextField ? 'type' : 'select'}.',
  ].join('. ');
}
