import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/admin_repository.dart';

const _categoryOptions = [
  'identity',
  'transport',
  'revenue',
  'law_enforcement',
  'basic_education',
  'higher_education',
  'social_security',
  'labour',
  'other',
];

/// Admin-only "Add Department" -- departments were previously seed data
/// only, with no in-app create flow (see docs/FUTURE_WORK.md).
class DepartmentFormScreen extends ConsumerStatefulWidget {
  const DepartmentFormScreen({super.key});

  @override
  ConsumerState<DepartmentFormScreen> createState() => _DepartmentFormScreenState();
}

class _DepartmentFormScreenState extends ConsumerState<DepartmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  String _category = _categoryOptions.first;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(adminRepositoryProvider).createDepartment(
            departmentCode: _codeController.text.trim().toUpperCase(),
            departmentName: _nameController.text.trim(),
            category: _category,
            contactEmail: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
            contactPhone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          );
      ref.invalidate(adminDepartmentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Department created.')));
        context.pop();
      }
    } catch (e) {
      setState(() => _error = 'Could not create this department: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Department')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'Department code (e.g. HOME_AFFAIRS)',
                  controller: _codeController,
                  prefixIcon: Icons.tag_outlined,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a short code' : null,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Department name',
                  controller: _nameController,
                  prefixIcon: Icons.account_balance_outlined,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the department\'s name' : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_outlined)),
                  items: [for (final c in _categoryOptions) DropdownMenuItem(value: c, child: Text(c))],
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Contact email (optional)',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.mail_outline,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Contact phone (optional)',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.call_outlined,
                ),
                const SizedBox(height: 8),
                const Text(
                  'A new department has no dedicated record types or dashboard '
                  'stats until those are added in code -- creating it here lets '
                  'officials be assigned to it and credential types be issued '
                  'under it.',
                  style: TextStyle(color: AppColors.charcoalMuted, fontSize: 12),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                AppButton(
                  label: 'Create department',
                  icon: Icons.add_business_outlined,
                  loading: _submitting,
                  expand: true,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
