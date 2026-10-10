import 'package:flutter/material.dart';

import 'app_form_dialog.dart';

/// The safety check in front of an administrator action that cuts someone
/// off (revoke, decline, suspend, delete): it spells out what will happen,
/// makes the admin type [confirmText] (usually the organisation's or
/// person's name) and, when [askReason] is set, give a reason.
///
/// Returns the reason (empty when [askReason] is false), or null if the
/// admin cancelled.
Future<String?> confirmDestructive(
  BuildContext context, {
  required String title,
  required String consequence,
  required String confirmText,
  required String confirmLabel,
  bool askReason = true,
  String reasonLabel = 'Reason (required)',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _ConfirmDestructiveDialog(
      title: title,
      consequence: consequence,
      confirmText: confirmText,
      confirmLabel: confirmLabel,
      askReason: askReason,
      reasonLabel: reasonLabel,
    ),
  );
}

class _ConfirmDestructiveDialog extends StatefulWidget {
  const _ConfirmDestructiveDialog({
    required this.title,
    required this.consequence,
    required this.confirmText,
    required this.confirmLabel,
    required this.askReason,
    required this.reasonLabel,
  });

  final String title;
  final String consequence;
  final String confirmText;
  final String confirmLabel;
  final bool askReason;
  final String reasonLabel;

  @override
  State<_ConfirmDestructiveDialog> createState() => _ConfirmDestructiveDialogState();
}

class _ConfirmDestructiveDialogState extends State<_ConfirmDestructiveDialog> {
  final _typed = TextEditingController();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    _reason.dispose();
    super.dispose();
  }

  String _normalise(String v) => v.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  bool get _ready =>
      _normalise(_typed.text) == _normalise(widget.confirmText) &&
      (!widget.askReason || _reason.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppFormDialog(
      title: widget.title,
      submitLabel: widget.confirmLabel,
      destructive: true,
      onSubmit: _ready ? () => Navigator.pop(context, _reason.text.trim()) : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.consequence),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'To confirm, type '),
              TextSpan(text: widget.confirmText, style: const TextStyle(fontWeight: FontWeight.w700)),
              const TextSpan(text: ' below.'),
            ]),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _typed,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: widget.confirmText),
          ),
          if (widget.askReason) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _reason,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: widget.reasonLabel),
            ),
          ],
        ],
      ),
    );
  }
}
