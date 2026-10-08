import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../data/citizen_repository.dart';
import 'identity_card.dart';

/// A simple digital-ID-card presentation for the citizen's own identity --
/// the kind of screen a real digital-ID app leads with. The QR code
/// encodes the citizen's ID number so an official/organisation could, in
/// a future phase, scan-to-search instead of typing it in. Purely a
/// display of data the citizen can already see elsewhere (Digital
/// Identity / Personal Information) -- no new table, no new permission.
class DigitalIdCardScreen extends ConsumerWidget {
  const DigitalIdCardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(digitalIdentityProvider);

    return Scaffold(
      backgroundColor: AppColors.charcoal,
      appBar: AppBar(
        title: const Text('Digital ID'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: identityAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => const ErrorView(message: 'Could not load your digital ID.'),
        data: (identity) => Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Hero(
                tag: 'digital-id-card-hero',
                child: IdentityCard(identity: identity, alignment: Alignment.center),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
