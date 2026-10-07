import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/citizen_lookup_result.dart';

/// Citizen search by any combination of first name, last name and/or ID
/// number, plus a "View all" browse, ending in a selectable result list --
/// shared by every department official's dashboard and the administrator
/// area (spec §3.2/§3.4). Not riverpod-provider-backed since it's reused
/// across roles/repositories -- [onSearch] is whichever repository's own
/// `searchCitizens`.
///
/// [CitizenLookupScreen] wraps this in its own `Scaffold` for standalone
/// use; [DepartmentCitizenRecordsScreen] embeds the bare panel instead,
/// since that screen already has its own `Scaffold`/app bar and its own
/// "then show this department's records" step after a citizen is picked.
class CitizenSearchPanel extends StatefulWidget {
  const CitizenSearchPanel({super.key, required this.onSearch, required this.onSelect, this.initialIdNumber});

  final Future<List<CitizenLookupResult>> Function({String? idNumber, String? firstName, String? lastName}) onSearch;
  final void Function(CitizenLookupResult citizen) onSelect;

  /// Pre-fills the ID number field and runs the search immediately -- e.g.
  /// an ID typed into the department header's search field.
  final String? initialIdNumber;

  @override
  State<CitizenSearchPanel> createState() => _CitizenSearchPanelState();
}

class _CitizenSearchPanelState extends State<CitizenSearchPanel> {
  final _idNumberController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _searched = false;
  bool _loading = false;
  String? _error;
  List<CitizenLookupResult>? _results;

  @override
  void initState() {
    super.initState();
    final initialId = widget.initialIdNumber?.trim() ?? '';
    if (initialId.isNotEmpty) {
      _idNumberController.text = initialId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runSearch(browseAll: false);
      });
    }
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _runSearch({required bool browseAll}) async {
    final idNumber = _idNumberController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    if (!browseAll && idNumber.isEmpty && firstName.isEmpty && lastName.isEmpty) return;
    setState(() {
      _searched = true;
      _loading = true;
      _error = null;
      _results = null;
    });
    try {
      final results = await widget.onSearch(
        idNumber: browseAll ? null : (idNumber.isEmpty ? null : idNumber),
        firstName: browseAll ? null : (firstName.isEmpty ? null : firstName),
        lastName: browseAll ? null : (lastName.isEmpty ? null : lastName),
      );
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not complete this search: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: 'ID number',
          controller: _idNumberController,
          keyboardType: TextInputType.number,
          prefixIcon: Icons.badge_outlined,
          onFieldSubmitted: (_) => _runSearch(browseAll: false),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                label: 'First name',
                controller: _firstNameController,
                prefixIcon: Icons.person_outline,
                onFieldSubmitted: (_) => _runSearch(browseAll: false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppTextField(
                label: 'Last name (surname)',
                controller: _lastNameController,
                prefixIcon: Icons.person_outline,
                onFieldSubmitted: (_) => _runSearch(browseAll: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Search',
                icon: Icons.search,
                loading: _loading,
                onPressed: _loading ? null : () => _runSearch(browseAll: false),
              ),
            ),
            const SizedBox(width: 10),
            TextButton.icon(
              onPressed: _loading ? null : () => _runSearch(browseAll: true),
              icon: const Icon(Icons.list_alt_outlined, size: 18),
              label: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (!_searched) {
      return const EmptyState(
        icon: Icons.person_search_outlined,
        title: 'Search by name or ID number',
        message: 'Enter any combination of first name, last name or ID number, or tap "View all" to browse.',
      );
    }
    if (_loading) return const LoadingIndicator();
    if (_error != null) {
      return EmptyState(icon: Icons.error_outline, title: 'Search failed', message: _error!);
    }
    final results = _results ?? const [];
    if (results.isEmpty) {
      return const EmptyState(
        icon: Icons.person_off_outlined,
        title: 'No citizen found',
        message: 'No citizen matches this search.',
      );
    }
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final r = results[i];
        return ListItemCard(
          leadingIcon: Icons.person_outline,
          title: r.fullName.isEmpty ? 'Unknown' : r.fullName,
          subtitle: r.idNumber,
          trailing: StatusBadge.fromStatus(r.currentStatus),
          onTap: () => widget.onSelect(r),
        );
      },
    );
  }
}

/// Standalone search screen -- [CitizenSearchPanel] in its own `Scaffold`,
/// defaulting to a detail bottom sheet on selection (the identity-only view
/// this screen has always shown).
class CitizenLookupScreen extends StatelessWidget {
  const CitizenLookupScreen({super.key, required this.onSearch, this.initialIdNumber});

  final Future<List<CitizenLookupResult>> Function({String? idNumber, String? firstName, String? lastName}) onSearch;
  final String? initialIdNumber;

  void _showDetail(BuildContext context, CitizenLookupResult citizen) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DetailRow(label: 'Name', value: citizen.fullName.isEmpty ? 'Unknown' : citizen.fullName),
            DetailRow(label: 'ID number', value: citizen.idNumber),
            if (citizen.dateOfBirth != null)
              DetailRow(label: 'Date of birth', value: AppFormatters.date(citizen.dateOfBirth!)),
            if (citizen.phoneNumber != null && citizen.phoneNumber!.isNotEmpty)
              DetailRow(label: 'Phone', value: citizen.phoneNumber!),
            if (citizen.email != null && citizen.email!.isNotEmpty) DetailRow(label: 'Email', value: citizen.email!),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const SizedBox(width: 130, child: Text('Identity status')),
                  StatusBadge.fromStatus(citizen.currentStatus),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Citizen')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: CitizenSearchPanel(
          onSearch: onSearch,
          initialIdNumber: initialIdNumber,
          onSelect: (citizen) => _showDetail(context, citizen),
        ),
      ),
    );
  }
}
