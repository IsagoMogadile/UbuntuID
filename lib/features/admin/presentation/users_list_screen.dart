import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/report_export.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/widgets/staggered_fade_in.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../routing/app_routes.dart';
import '../data/admin_repository.dart';
import '../domain/user_list_item.dart';

/// Admin's unified view across all 4 role tables. Accepts an optional
/// starting filter (e.g. from a dashboard stat card's "50 citizens" ->
/// tap -> this screen, pre-filtered to citizens) via [initialRoleFilter];
/// filter chips let the admin switch it afterwards.
class UsersListScreen extends ConsumerStatefulWidget {
  const UsersListScreen({super.key, this.initialRoleFilter});

  final AdminUserRole? initialRoleFilter;

  @override
  ConsumerState<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends ConsumerState<UsersListScreen> {
  AdminUserRole? _filter;
  bool _filterInitialised = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<UserListItem> _visibleUsers() {
    final all = ref.read(adminUsersProvider).value ?? const <UserListItem>[];
    final query = _searchController.text.trim().toLowerCase();
    return all.where((u) {
      if (_filter != null && u.role != _filter) return false;
      if (query.isEmpty) return true;
      return u.displayName.toLowerCase().contains(query) || u.email.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _exportExcel() async {
    final users = _visibleUsers();
    await ReportExport.exportExcel(
      filename: 'UbuntuID_Users.xlsx',
      title: 'Users',
      headers: const ['Name', 'Email', 'Role', 'Status', 'Created'],
      rows: [
        for (final u in users)
          [u.displayName, u.email, u.roleLabel, u.active ? 'Active' : 'Inactive', u.createdAt.toLocal().toIso8601String().split('T').first],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // didUpdateWidget isn't triggered by a new query param on the same
    // route instance in some navigation paths, so apply the starting
    // filter once, on first build, rather than in initState (widget
    // isn't fully attached yet there).
    if (!_filterInitialised) {
      _filter = widget.initialRoleFilter;
      _filterInitialised = true;
    }

    final usersAsync = ref.watch(adminUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(icon: const Icon(Icons.download_outlined), tooltip: 'Export Excel', onPressed: _exportExcel),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.adminOfficialNew),
        icon: const Icon(Icons.person_add_alt_outlined),
        label: const Text('Add official'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: AppTextField(
              label: 'Search by name or email',
              controller: _searchController,
              prefixIcon: Icons.search,
              onFieldSubmitted: (_) {},
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(label: 'All', selected: _filter == null, onSelected: () => setState(() => _filter = null)),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Citizens',
                    selected: _filter == AdminUserRole.citizen,
                    onSelected: () => setState(() => _filter = AdminUserRole.citizen),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Officials',
                    selected: _filter == AdminUserRole.departmentOfficial,
                    onSelected: () => setState(() => _filter = AdminUserRole.departmentOfficial),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Organisation users',
                    selected: _filter == AdminUserRole.organisationUser,
                    onSelected: () => setState(() => _filter = AdminUserRole.organisationUser),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Administrators',
                    selected: _filter == AdminUserRole.administrator,
                    onSelected: () => setState(() => _filter = AdminUserRole.administrator),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: usersAsync.when(
              loading: () => const ShimmerListPlaceholder(itemCount: 8, padding: EdgeInsets.fromLTRB(16, 8, 16, 96)),
              error: (error, _) => ErrorView(
                message: 'Could not load users.',
                onRetry: () => ref.invalidate(adminUsersProvider),
              ),
              data: (allUsers) {
                final query = _searchController.text.trim().toLowerCase();
                final users = allUsers.where((u) {
                  if (_filter != null && u.role != _filter) return false;
                  if (query.isEmpty) return true;
                  return u.displayName.toLowerCase().contains(query) || u.email.toLowerCase().contains(query);
                }).toList();
                if (users.isEmpty) {
                  return const EmptyState(icon: Icons.group_outlined, title: 'No users found');
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: users.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return StaggeredFadeIn(
                      index: index,
                      child: ListItemCard(
                        title: user.displayName,
                        subtitle: '${user.email} • ${user.roleLabel}',
                        leadingIcon: Icons.person_outline,
                        trailing: StatusBadge.fromStatus(user.active ? 'active' : 'inactive'),
                        onTap: () => context.push('${AppRoutes.adminUsers}/${user.userId}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onSelected});

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onSelected());
  }
}
