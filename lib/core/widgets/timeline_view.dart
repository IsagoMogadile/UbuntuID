import 'package:flutter/material.dart';

class TimelineStepData {
  const TimelineStepData({
    required this.label,
    this.timestamp,
    this.completed = false,
    this.description,
  });

  final String label;
  final String? timestamp;
  final bool completed;
  final String? description;
}

/// A simple vertical status timeline, used for application/verification
/// progress. Steps are supplied by the caller -- this widget has no opinion
/// on what the real workflow stages are.
class TimelineView extends StatelessWidget {
  const TimelineView({super.key, required this.steps});

  final List<TimelineStepData> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          _buildStep(context, steps[i], isLast: i == steps.length - 1),
      ],
    );
  }

  Widget _buildStep(BuildContext context, TimelineStepData step, {required bool isLast}) {
    final scheme = Theme.of(context).colorScheme;
    final dotColor = step.completed ? scheme.primary : scheme.surface;
    final ringColor = step.completed ? scheme.primary : scheme.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  border: Border.all(color: ringColor, width: 2),
                ),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: scheme.outlineVariant)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (step.timestamp != null)
                    Text(
                      step.timestamp!,
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                    ),
                  if (step.description != null) ...[
                    const SizedBox(height: 4),
                    Text(step.description!, style: const TextStyle(fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
