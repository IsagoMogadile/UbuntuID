import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/citizen_lookup_result.dart';

/// Generic "search citizen by ID number" screen, shared by every department
/// official's dashboard and the administrator area (spec §3.2/§3.4). Not
/// riverpod-provider-backed since it's reused across roles/repositories --
/// [onSearch] is whichever repository's own `searchCitizenByIdNumber`.
class CitizenLookupScreen extends StatefulWidget {
  const CitizenLookupScreen({super.key, required this.onSearch});

  final Future<CitizenLookupResult?> Function(String idNumber) onSearch;

  @override
  State<CitizenLookupScreen> createState() => _CitizenLookupScreenState();
}

class _CitizenLookupScreenState extends State<CitizenLookupScreen> {
  final _idNumberController = TextEditingController();
  bool _searched = false;
  bool _loading = false;
  String? _error;
  CitizenLookupResult? _result;

  @override
  void dispose() {
    _idNumberController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final value = _idNumberController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _searched = true;
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await widget.onSearch(value);
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not complete this search: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Citizen')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'ID number',
                    controller: _idNumberController,
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.badge_outlined,
                    onFieldSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 10),
                AppButton(label: 'Search', icon: Icons.search, loading: _loading, onPressed: _loading ? null : _search),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_searched) {
      return const EmptyState(
        icon: Icons.person_search_outlined,
        title: 'Search by ID number',
        message: 'Enter a South African ID number to look up a citizen\'s identity record.',
      );
    }
    if (_loading) return const LoadingIndicator();
    if (_error != null) {
      return EmptyState(icon: Icons.error_outline, title: 'Search failed', message: _error!);
    }
    final result = _result;
    if (result == null) {
      return const EmptyState(
        icon: Icons.person_off_outlined,
        title: 'No citizen found',
        message: 'No citizen matches this ID number.',
      );
    }
    return ListView(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DetailRow(label: 'Name', value: result.fullName.isEmpty ? 'Unknown' : result.fullName),
              DetailRow(label: 'ID number', value: result.idNumber),
              if (result.dateOfBirth != null)
                DetailRow(label: 'Date of birth', value: AppFormatters.date(result.dateOfBirth!)),
              if (result.phoneNumber != null && result.phoneNumber!.isNotEmpty)
                DetailRow(label: 'Phone', value: result.phoneNumber!),
              if (result.email != null && result.email!.isNotEmpty)
                DetailRow(label: 'Email', value: result.email!),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const SizedBox(width: 130, child: Text('Identity status')),
                    StatusBadge.fromStatus(result.currentStatus),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
