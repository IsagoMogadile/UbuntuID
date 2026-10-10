import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/verification_repository.dart';
import '../domain/verification_request_summary.dart';

/// Shared list body used by the department official, organisation and
/// administrator "Verification" screens. [searchable] adds a name search
/// above the list (the organisation's Applicants screen).
class VerificationRequestListView extends ConsumerStatefulWidget {
  const VerificationRequestListView({super.key, required this.onOpen, this.searchable = false});

  final void Function(String requestId) onOpen;
  final bool searchable;

  @override
  ConsumerState<VerificationRequestListView> createState() => _VerificationRequestListViewState();
}

class _VerificationRequestListViewState extends ConsumerState<VerificationRequestListView> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Every word typed must appear somewhere in the name, in any order, so
  /// "mogadile kopano" and "kop" both find Kopano Mogadile.
  bool _matches(VerificationRequestSummary request) {
    final words = _query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final name = request.citizenDisplayName.toLowerCase();
    return words.every(name.contains);
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(verificationRequestsProvider);

    return requestsAsync.when(
      loading: () => const LoadingIndicator(),
      error: (error, _) => ErrorView(
        message: 'Could not load verification requests.',
        onRetry: () => ref.invalidate(verificationRequestsProvider),
      ),
      data: (requests) {
        if (requests.isEmpty) {
          return const EmptyState(
            icon: Icons.fact_check_outlined,
            title: 'No verification requests',
            message: 'New requests will appear here.',
          );
        }

        final visible = widget.searchable ? requests.where(_matches).toList() : requests;

        return Column(
          children: [
            if (widget.searchable)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: InputDecoration(
                    labelText: 'Search applicants by name',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() {
                              _searchController.clear();
                              _query = '';
                            }),
                          ),
                  ),
                ),
              ),
            Expanded(
              child: visible.isEmpty
                  ? EmptyState(
                      icon: Icons.search_off_outlined,
                      title: 'No applicants match "$_query"',
                      message: 'Check the spelling, or search by first or last name only.',
                    )
                  : RefreshIndicator(
                      onRefresh: () => ref.refresh(verificationRequestsProvider.future),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final request = visible[index];
                          return ListItemCard(
                            title: request.citizenDisplayName,
                            subtitle: '${request.organisationName} • ${AppFormatters.date(request.requestedAt)}',
                            leadingIcon: Icons.fact_check_outlined,
                            trailing: StatusBadge.fromStatus(request.decision ?? request.overallStatus),
                            onTap: () => widget.onOpen(request.requestId),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
