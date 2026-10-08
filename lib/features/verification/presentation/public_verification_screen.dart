import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../routing/app_routes.dart';
import '../data/public_verification_repository.dart';
import '../domain/public_document.dart';
import '../domain/public_verification_result.dart';

/// Where a scanned QR code lands. Public -- no sign-in. Shows whether the
/// document is current, then the document itself (the same prototype PDF
/// the citizen downloads), which the viewer can download, share or print.
class PublicVerificationScreen extends ConsumerWidget {
  const PublicVerificationScreen({super.key, required this.docRef});

  final String docRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = ref.watch(publicVerificationProvider(docRef));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document check'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(onPressed: () => context.go(AppRoutes.login), child: const Text('Go to UbuntuID')),
        ],
      ),
      body: resultAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => const _Outcome(
          icon: Icons.cloud_off_outlined,
          color: AppColors.charcoalMuted,
          title: 'Check unavailable',
          message: 'This document could not be checked right now. Please try again later.',
        ),
        data: (result) => result == null
            ? const _Outcome(
                icon: Icons.gpp_bad_outlined,
                color: AppColors.error,
                title: 'Not recognised',
                message: 'No UbuntuID document matches this code. It may have been altered, '
                    'or it is not an UbuntuID QR code.',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatusBar(result: result),
                  Expanded(child: _DocumentView(docRef: docRef)),
                ],
              ),
      ),
    );
  }
}

/// One-line verdict above the document: is it genuine and current?
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.result});

  final PublicVerificationResult result;

  @override
  Widget build(BuildContext context) {
    final (icon, color, title) = switch (StatusBadge.toneForStatus(result.status)) {
      AppStatusTone.success => (Icons.verified_outlined, AppColors.success, 'Valid document'),
      AppStatusTone.error => (Icons.gpp_bad_outlined, AppColors.error, 'Not valid'),
      _ => (Icons.hourglass_top_outlined, AppColors.warning, 'Not yet confirmed'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16)),
                Text('${result.document} · ${result.issuer}', style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          StatusBadge.fromStatus(result.status),
        ],
      ),
    );
  }
}

class _DocumentView extends ConsumerWidget {
  const _DocumentView({required this.docRef});

  final String docRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(publicDocumentProvider(docRef)).when(
          loading: () => const LoadingIndicator(),
          error: (error, _) => const _Outcome(
            icon: Icons.description_outlined,
            color: AppColors.charcoalMuted,
            title: 'Document unavailable',
            message: 'The document could not be opened right now. Its status above is still current.',
          ),
          data: (document) => document == null
              ? const _Outcome(
                  icon: Icons.description_outlined,
                  color: AppColors.charcoalMuted,
                  title: 'Document unavailable',
                  message: 'There is no document to show for this code.',
                )
              : _Pdf(document: document),
        );
  }
}

class _Pdf extends StatelessWidget {
  const _Pdf({required this.document});

  final PublicDocument document;

  @override
  Widget build(BuildContext context) {
    return PdfPreview(
      build: (_) => document.buildPdf(),
      pdfFileName: document.fileName,
      canChangeOrientation: false,
      canChangePageFormat: false,
      canDebug: false,
      loadingWidget: const LoadingIndicator(),
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({required this.icon, required this.color, required this.title, required this.message});

  final IconData icon;
  final Color color;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              const AppLogo(size: 44),
              const SizedBox(height: 24),
              Icon(icon, size: 64, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
