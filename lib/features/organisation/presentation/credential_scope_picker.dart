import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/organisation_repository.dart';

/// What an organisation asks for at registration (and resubmission): an
/// overall purpose plus a reason for every credential type it ticks. The
/// administrator who approves the application sees all of it.
class CredentialScopeSelection {
  final purpose = TextEditingController();
  final Set<String> selected = {};
  final Map<String, TextEditingController> _reasons = {};

  TextEditingController reasonFor(String typeCode) => _reasons.putIfAbsent(typeCode, TextEditingController.new);

  Map<String, String> get reasons => {
        for (final code in selected) code: reasonFor(code).text.trim(),
      };

  /// First problem to show the user, or null when complete.
  String? validate() {
    if (purpose.text.trim().isEmpty) return 'Explain why your organisation needs access to UbuntuID.';
    if (selected.isEmpty) return 'Select at least one credential type your organisation needs to verify.';
    if (selected.any((code) => reasonFor(code).text.trim().isEmpty)) {
      return 'Give a reason for each credential type you selected.';
    }
    return null;
  }

  void dispose() {
    purpose.dispose();
    for (final c in _reasons.values) {
      c.dispose();
    }
  }
}

class CredentialScopePicker extends StatelessWidget {
  const CredentialScopePicker({
    super.key,
    required this.selection,
    required this.types,
    required this.onChanged,
    this.showDepartment = true,
  });

  final CredentialScopeSelection selection;
  final List<CredentialTypeOption> types;
  final VoidCallback onChanged;
  final bool showDepartment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: selection.purpose,
          maxLines: 3,
          minLines: 2,
          decoration: const InputDecoration(
            labelText: 'Why does your organisation need access?',
            hintText: 'e.g. We are a logistics company that vets drivers before hiring them.',
          ),
        ),
        const SizedBox(height: 12),
        for (final type in types) ...[
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: selection.selected.contains(type.typeCode),
            onChanged: (checked) {
              if (checked ?? false) {
                selection.selected.add(type.typeCode);
              } else {
                selection.selected.remove(type.typeCode);
              }
              onChanged();
            },
            title: Text(type.displayName),
            subtitle: showDepartment ? Text(type.issuingDepartment) : null,
          ),
          if (selection.selected.contains(type.typeCode))
            Padding(
              padding: const EdgeInsets.only(left: 32, bottom: 8),
              child: TextField(
                controller: selection.reasonFor(type.typeCode),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'Why do you need ${type.displayName}?',
                  labelStyle: const TextStyle(fontSize: 13, color: AppColors.charcoalMuted),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
