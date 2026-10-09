import 'package:flutter/material.dart';

/// The layout for any pop-up that asks the user to fill something in
/// (offer employment, lodge an appeal, add a record...):
///
/// * a header with the title, an optional one-line explanation and a close
///   button;
/// * the fields, scrolling if they don't fit;
/// * a footer that stays visible, with Cancel and the main action named
///   after what it does.
///
/// Full screen on phones, a comfortable fixed width on larger screens.
/// Pop with a value from [onSubmit]'s caller; validation stays inside the
/// dialog so nothing typed is lost when something is missing.
class AppFormDialog extends StatelessWidget {
  const AppFormDialog({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    required this.submitLabel,
    required this.onSubmit,
    this.submitting = false,
    this.destructive = false,
    this.maxWidth = 560,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final String submitLabel;

  /// Null disables the main button.
  final VoidCallback? onSubmit;
  final bool submitting;
  final bool destructive;
  final double maxWidth;

  static const _phoneBreakpoint = 600.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isPhone = MediaQuery.sizeOf(context).width < _phoneBreakpoint;

    final body = Column(
      mainAxisSize: isPhone ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text(title, style: theme.textTheme.titleLarge)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: submitting ? null : () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: child,
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: destructive
                    ? FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError)
                    : null,
                onPressed: submitting ? null : onSubmit,
                child: submitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.4))
                    : Text(submitLabel),
              ),
            ],
          ),
        ),
      ],
    );

    if (isPhone) return Dialog.fullscreen(child: SafeArea(child: body));
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        child: body,
      ),
    );
  }
}

/// A small heading that groups fields inside an [AppFormDialog].
class FormSectionLabel extends StatelessWidget {
  const FormSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

/// A date shown like a text field, opening the date picker when tapped.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onPicked,
    this.firstDate,
    this.lastDate,
    this.initialDate,
    this.errorText,
    this.helperText,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPicked;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final DateTime? initialDate;
  final String? errorText;
  final String? helperText;

  static String _format(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? initialDate ?? DateTime.now(),
          firstDate: firstDate ?? DateTime(1900),
          lastDate: lastDate ?? DateTime(2100),
        );
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          helperText: helperText,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        isEmpty: value == null,
        child: value == null ? null : Text(_format(value!)),
      ),
    );
  }
}
