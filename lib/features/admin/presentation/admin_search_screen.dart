import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../routing/app_routes.dart';
import '../data/admin_repository.dart';
import '../domain/admin_search_hit.dart';

/// The administrator's universal search, reached from the admin header's
/// search field: one box that finds any actor UbuntuID knows about --
/// citizens, department officials, organisation users, administrators,
/// organisations and departments -- by name, ID number, registration number,
/// department code or email. Results are grouped by kind, can be narrowed
/// with the filter chips, and open that actor's own admin detail screen.
/// [initialQuery] is whatever was typed in the header (`?q=`), searched
/// immediately.
class AdminSearchScreen extends ConsumerStatefulWidget {
  const AdminSearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<AdminSearchScreen> createState() => _AdminSearchScreenState();
}

class _AdminSearchScreenState extends ConsumerState<AdminSearchScreen> {
  static const _debounce = Duration(milliseconds: 350);

  final _controller = TextEditingController();
  Timer? _debounceTimer;
  // Bumped on every search so a slow, superseded request can't overwrite
  // the results of a newer one.
  int _searchGeneration = 0;
  bool _loading = false;
  String? _error;
  List<AdminSearchHit>? _results;
  AdminSearchKind? _kindFilter;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery?.trim() ?? '';
    if (initial.isNotEmpty) {
      _controller.text = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runSearch(initial);
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {}); // show/hide the clear button
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => _runSearch(value));
  }

  Future<void> _runSearch(String value) async {
    _debounceTimer?.cancel();
    final query = value.trim();
    final generation = ++_searchGeneration;
    if (query.isEmpty) {
      setState(() {
        _loading = false;
        _error = null;
        _results = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ref.read(adminRepositoryProvider).searchEverything(query);
      if (mounted && generation == _searchGeneration) setState(() => _results = results);
    } catch (e) {
      if (mounted && generation == _searchGeneration) setState(() => _error = 'Could not complete this search: $e');
    } finally {
      if (mounted && generation == _searchGeneration) setState(() => _loading = false);
    }
  }

  void _open(AdminSearchHit hit) {
    final base = switch (hit.kind) {
      AdminSearchKind.citizen ||
      AdminSearchKind.departmentOfficial ||
      AdminSearchKind.organisationUser ||
      AdminSearchKind.administrator =>
        AppRoutes.adminUsers,
      AdminSearchKind.organisation => AppRoutes.adminOrganisations,
      AdminSearchKind.department => AppRoutes.adminDepartments,
    };
    context.push('$base/${hit.id}');
  }

  static IconData _iconFor(AdminSearchKind kind) => switch (kind) {
        AdminSearchKind.citizen => Icons.person_outline,
        AdminSearchKind.departmentOfficial => Icons.badge_outlined,
        AdminSearchKind.organisationUser => Icons.work_outline,
        AdminSearchKind.administrator => Icons.admin_panel_settings_outlined,
        AdminSearchKind.organisation => Icons.apartment_outlined,
        AdminSearchKind.department => Icons.account_balance_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              autofocus: widget.initialQuery?.trim().isEmpty ?? true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: _runSearch,
              decoration: InputDecoration(
                hintText: 'Name, ID number, registration number or department code',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear',
                        onPressed: () {
                          _controller.clear();
                          _runSearch('');
                        },
                      ),
              ),
            ),
            const SizedBox(height: 12),
            _buildFilters(),
            const SizedBox(height: 12),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final results = _results ?? const <AdminSearchHit>[];
    int countOf(AdminSearchKind kind) => results.where((r) => r.kind == kind).length;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: Text(_results == null ? 'All' : 'All (${results.length})'),
            selected: _kindFilter == null,
            onSelected: (_) => setState(() => _kindFilter = null),
          ),
          for (final kind in AdminSearchKind.values) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              avatar: Icon(_iconFor(kind), size: 16),
              label: Text(_results == null ? kind.label : '${kind.label} (${countOf(kind)})'),
              selected: _kindFilter == kind,
              onSelected: (_) => setState(() => _kindFilter = _kindFilter == kind ? null : kind),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _results == null) return const LoadingIndicator();
    if (_error != null) {
      return EmptyState(icon: Icons.error_outline, title: 'Search failed', message: _error!);
    }
    final results = _results;
    if (results == null) {
      return const EmptyState(
        icon: Icons.manage_search_outlined,
        title: 'Search everyone on UbuntuID',
        message: 'Find citizens, officials, organisation users and administrators by name or ID number, '
            'or organisations and departments by name.',
      );
    }
    final visible = _kindFilter == null ? results : results.where((r) => r.kind == _kindFilter).toList();
    if (visible.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_outlined,
        title: 'No matches',
        message: _kindFilter == null
            ? 'Nothing on UbuntuID matches this search.'
            : 'No ${_kindFilter!.label.toLowerCase()} match this search.',
      );
    }

    return ListView(
      children: [
        if (_loading) const LinearProgressIndicator(),
        for (final kind in AdminSearchKind.values)
          if (visible.any((r) => r.kind == kind)) ...[
            SectionHeader(title: kind.label),
            for (final hit in visible.where((r) => r.kind == kind)) ...[
              ListItemCard(
                leadingIcon: _iconFor(kind),
                title: hit.title.isEmpty ? 'Unknown' : hit.title,
                subtitle: hit.subtitle.isEmpty ? null : hit.subtitle,
                trailing: StatusBadge.fromStatus(hit.status),
                onTap: () => _open(hit),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}
