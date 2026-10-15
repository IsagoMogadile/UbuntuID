import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../routing/app_routes.dart';

const _dismissedKey = 'ubuntuid_guide_prompt_dismissed';

/// Whether a sign-in has just happened and the "Feeling lost?" pop-up is
/// still owed. Set by the login and register screens; the citizen pages
/// show the pop-up once and clear it, so it appears once per sign-in rather
/// than on every page.
class GuidePromptPending extends Notifier<bool> {
  @override
  bool build() => false;

  void signedIn() => state = true;

  void shown() => state = false;
}

final guidePromptPendingProvider = NotifierProvider<GuidePromptPending, bool>(GuidePromptPending.new);

/// Wraps the citizen pages: right after a citizen signs in, pops up a short
/// message pointing at the user guide, unless they ticked "Don't show this
/// again" before.
class GuidePromptOnSignIn extends ConsumerStatefulWidget {
  const GuidePromptOnSignIn({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<GuidePromptOnSignIn> createState() => _GuidePromptOnSignInState();
}

class _GuidePromptOnSignInState extends ConsumerState<GuidePromptOnSignIn> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  Future<void> _maybeShow() async {
    if (!mounted || !ref.read(guidePromptPendingProvider)) return;
    ref.read(guidePromptPendingProvider.notifier).shown();
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_dismissedKey) ?? false) return;
    if (!mounted) return;
    final choice = await showDialog<({bool open, bool dontShowAgain})>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _GuidePromptDialog(),
    );
    if (choice == null) return;
    if (choice.dontShowAgain) await prefs.setBool(_dismissedKey, true);
    if (choice.open && mounted) context.push(AppRoutes.citizenGuide);
  }

  @override
  Widget build(BuildContext context) {
    // Also catches a sign-in while this widget is already on screen.
    ref.listen(guidePromptPendingProvider, (_, pending) {
      if (pending) WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
    });
    return widget.child;
  }
}

class _GuidePromptDialog extends StatefulWidget {
  const _GuidePromptDialog();

  @override
  State<_GuidePromptDialog> createState() => _GuidePromptDialogState();
}

class _GuidePromptDialogState extends State<_GuidePromptDialog> {
  bool _dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      scrollable: true,
      icon: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.goldLight, shape: BoxShape.circle),
        child: const Icon(Icons.menu_book_outlined, size: 32, color: AppColors.warning),
      ),
      title: const Text('Feeling lost? We have a guide'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'The UbuntuID guide shows you, with pictures, where to find your ID card, documents, '
            'services and settings. You can also download it as a PDF.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          // Show them exactly what to look for.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Expanded(child: Text('Open it any time with the Guide button at the top of the screen:')),
                const SizedBox(width: 10),
                Chip(
                  avatar: const Icon(Icons.help_outline, size: 18),
                  label: const Text('Guide'),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: theme.colorScheme.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          CheckboxListTile(
            value: _dontShowAgain,
            onChanged: (v) => setState(() => _dontShowAgain = v ?? false),
            title: const Text("Don't show this again"),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, (open: false, dontShowAgain: _dontShowAgain)),
          child: const Text('Maybe later'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, (open: true, dontShowAgain: _dontShowAgain)),
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('Open the guide'),
        ),
      ],
    );
  }
}
