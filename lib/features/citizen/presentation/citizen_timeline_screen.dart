import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/timeline_view.dart';
import '../data/citizen_repository.dart';

/// A chronological "life events" feed -- everything UbuntuID knows was
/// issued to this citizen and when, in one scrollable view instead of
/// scattered across Digital Identity/Documents/department screens.
class CitizenTimelineScreen extends ConsumerWidget {
  const CitizenTimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(lifeTimelineProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Timeline')),
      body: timelineAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: 'Could not load your timeline.',
          onRetry: () => ref.invalidate(lifeTimelineProvider),
        ),
        data: (events) {
          if (events.isEmpty) {
            return const EmptyState(
              icon: Icons.timeline_outlined,
              title: 'Nothing on record yet',
              message: 'Events will appear here as departments issue you credentials and records.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TimelineView(
                steps: [
                  for (final event in events)
                    TimelineStepData(
                      label: event.title,
                      timestamp: AppFormatters.date(event.date),
                      description: event.subtitle,
                      completed: true,
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
