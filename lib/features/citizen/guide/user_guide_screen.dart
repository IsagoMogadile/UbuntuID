import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../routing/app_routes.dart';
import 'guide_mockups.dart';
import 'guide_pdf.dart';
import 'guide_topics.dart';

/// The citizen user guide: what each part of UbuntuID is for and how to get
/// there, with a picture of the screen for every topic. The same guide can
/// be downloaded as a PDF to keep or print.
class UserGuideScreen extends StatefulWidget {
  const UserGuideScreen({super.key});

  @override
  State<UserGuideScreen> createState() => _UserGuideScreenState();
}

class _UserGuideScreenState extends State<UserGuideScreen> {
  bool _downloading = false;
  int? _expanded = 0;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      await Printing.sharePdf(bytes: await GuidePdf.build(), filename: GuidePdf.fileName);
    } catch (_) {
      if (mounted) AppToast.error(context, 'Could not download the guide.');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User guide'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Download guide (PDF)',
            onPressed: _downloading ? null : _download,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _IntroCard(downloading: _downloading, onDownload: _download),
              const SizedBox(height: 20),
              for (final (i, topic) in citizenGuideTopics.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TopicCard(
                    number: i + 1,
                    topic: topic,
                    expanded: _expanded == i,
                    onToggle: () => setState(() => _expanded = _expanded == i ? null : i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.downloading, required this.onDownload});

  final bool downloading;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.green, AppColors.greenDark]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.menu_book_outlined, color: AppColors.goldLight, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'New to UbuntuID?',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap a topic below to see where it is and how to use it. In each picture, the parts to tap '
            'are circled in gold and numbered to match the steps.',
            style: TextStyle(color: Colors.white, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: downloading ? null : onDownload,
            style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.charcoal),
            icon: downloading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_outlined),
            label: Text(downloading ? 'Preparing...' : 'Download the guide (PDF)'),
          ),
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.number, required this.topic, required this.expanded, required this.onToggle});

  final int number;
  final GuideTopic topic;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(topic.icon, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text('$number. ${topic.title}', style: theme.textTheme.titleMedium),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          topic.where,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (expanded) _TopicDetail(topic: topic),
        ],
      ),
    );
  }
}

class _TopicDetail extends StatelessWidget {
  const _TopicDetail({required this.topic});

  final GuideTopic topic;

  @override
  Widget build(BuildContext context) {
    final picture = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: AspectRatio(
        aspectRatio: GuideMockup.width / GuideMockup.height,
        child: Semantics(
          label: 'Picture of the ${topic.title} screen, with the parts to tap numbered',
          child: SvgPicture.string(topic.mockup.toSvg()),
        ),
      ),
    );
    final details = _Steps(topic: topic);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 560) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [picture, const SizedBox(width: 24), Expanded(child: details)],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [details, const SizedBox(height: 16), Center(child: picture)],
          );
        },
      ),
    );
  }
}

const _tabRoutes = {
  AppRoutes.citizenDashboard,
  AppRoutes.citizenServices,
  AppRoutes.citizenNotifications,
  AppRoutes.citizenReports,
  AppRoutes.citizenSettings,
};

class _Steps extends StatelessWidget {
  const _Steps({required this.topic});

  final GuideTopic topic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final route = topic.route;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(topic.summary, style: const TextStyle(height: 1.4)),
        const SizedBox(height: 14),
        for (final (i, step) in topic.steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.gold,
                  child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Padding(padding: const EdgeInsets.only(top: 2), child: Text(step))),
              ],
            ),
          ),
        if (topic.tip != null)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark ? theme.colorScheme.surfaceContainerHighest : AppColors.goldLight,
              borderRadius: BorderRadius.circular(10),
              border: const Border(left: BorderSide(color: AppColors.gold, width: 4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, size: 20, color: AppColors.gold),
                const SizedBox(width: 8),
                Expanded(child: Text(topic.tip!)),
              ],
            ),
          ),
        if (route != null) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            // Bottom-bar pages are switched to; anything else opens on top
            // of the guide, so Back returns here.
            onPressed: () => _tabRoutes.contains(route) ? context.go(route) : context.push(route),
            icon: const Icon(Icons.arrow_forward),
            label: Text(topic.openLabel ?? 'Take me there'),
          ),
        ],
      ],
    );
  }
}
