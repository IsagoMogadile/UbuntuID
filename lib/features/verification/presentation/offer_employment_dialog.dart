import 'package:flutter/material.dart';

import '../../../core/widgets/app_form_dialog.dart';

/// What an organisation fills in to take an applicant on as staff.
class EmploymentTerms {
  const EmploymentTerms({
    required this.jobTitle,
    required this.departmentOrPosition,
    required this.salary,
    required this.salaryFrequency,
    required this.employmentType,
    required this.startDate,
    required this.endDate,
  });

  final String jobTitle;
  final String? departmentOrPosition;
  final num? salary;
  final String salaryFrequency;
  final String employmentType;
  final DateTime startDate;
  final DateTime? endDate;
}

/// Offer employment: role, pay and dates in three short groups, checked
/// inside the form so nothing typed is lost when something is missing.
/// Returns the terms, or null when cancelled.
Future<EmploymentTerms?> showOfferEmploymentDialog(BuildContext context, {required String applicantName}) {
  return showDialog<EmploymentTerms>(
    context: context,
    builder: (context) => _OfferEmploymentDialog(applicantName: applicantName),
  );
}

class _OfferEmploymentDialog extends StatefulWidget {
  const _OfferEmploymentDialog({required this.applicantName});

  final String applicantName;

  @override
  State<_OfferEmploymentDialog> createState() => _OfferEmploymentDialogState();
}

class _OfferEmploymentDialogState extends State<_OfferEmploymentDialog> {
  static const _types = ['Permanent', 'Fixed-term contract', 'Temporary', 'Internship'];

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _position = TextEditingController();
  final _salary = TextEditingController();
  String _frequency = 'Monthly';
  String _type = 'Permanent';
  DateTime _start = DateTime.now();
  DateTime? _end;
  bool _triedSubmit = false;

  bool get _needsEndDate => _type != 'Permanent';

  @override
  void dispose() {
    _title.dispose();
    _position.dispose();
    _salary.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _triedSubmit = true);
    final fieldsOk = _formKey.currentState?.validate() ?? false;
    if (!fieldsOk || (_needsEndDate && _end == null)) return;
    Navigator.of(context).pop(EmploymentTerms(
      jobTitle: _title.text.trim(),
      departmentOrPosition: _position.text.trim().isEmpty ? null : _position.text.trim(),
      salary: num.tryParse(_salary.text.trim().replaceAll(' ', '').replaceAll(',', '')),
      salaryFrequency: _frequency,
      employmentType: _type,
      startDate: _start,
      endDate: _needsEndDate ? _end : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      title: 'Offer employment',
      subtitle: '${widget.applicantName} will be added to your staff and notified.',
      submitLabel: 'Offer employment',
      onSubmit: _submit,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FormSectionLabel('Role'),
            TextFormField(
              controller: _title,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Job title', hintText: 'e.g. Junior accountant'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the job title.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _position,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Team or department (optional)', hintText: 'e.g. Finance'),
            ),
            const SizedBox(height: 16),
            Text('Employment type', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _types)
                  ChoiceChip(
                    label: Text(t),
                    selected: _type == t,
                    onSelected: (_) => setState(() {
                      _type = t;
                      if (!_needsEndDate) _end = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const FormSectionLabel('Pay'),
            TextFormField(
              controller: _salary,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Salary (optional)', prefixText: 'R '),
              validator: (v) {
                final text = (v ?? '').trim().replaceAll(' ', '').replaceAll(',', '');
                if (text.isEmpty) return null;
                final value = num.tryParse(text);
                return value == null || value < 0 ? 'Enter an amount in rand, e.g. 18500.' : null;
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final f in const ['Monthly', 'Annual'])
                  ChoiceChip(
                    label: Text(f == 'Monthly' ? 'Per month' : 'Per year'),
                    selected: _frequency == f,
                    onSelected: (_) => setState(() => _frequency = f),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const FormSectionLabel('Dates'),
            DateField(
              label: 'Start date',
              value: _start,
              firstDate: DateTime(2000),
              onPicked: (d) => setState(() {
                _start = d;
                if (_end != null && _end!.isBefore(d)) _end = null;
              }),
            ),
            if (_needsEndDate) ...[
              const SizedBox(height: 12),
              DateField(
                label: 'End date',
                value: _end,
                firstDate: _start,
                initialDate: _start.add(const Duration(days: 365)),
                helperText: 'Required for ${_type.toLowerCase()} positions.',
                errorText: _triedSubmit && _end == null ? 'Choose when this position ends.' : null,
                onPicked: (d) => setState(() => _end = d),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
