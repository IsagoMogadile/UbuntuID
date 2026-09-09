import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../data/citizen_repository.dart';

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
              constraints: const BoxConstraints(maxWidth: 380),
              child: Hero(
                tag: 'digital-id-card-hero',
                child: _IdCard(
                  fullName: identity.fullName,
                  idNumber: identity.idNumber,
                  dateOfBirth: AppFormatters.date(identity.dateOfBirth),
                  status: identity.currentStatus,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IdCard extends StatelessWidget {
  const _IdCard({
    required this.fullName,
    required this.idNumber,
    required this.dateOfBirth,
    required this.status,
  });

  final String fullName;
  final String idNumber;
  final String dateOfBirth;
  final String status;

  @override
  Widget build(BuildContext context) {
    final active = status.toLowerCase() == 'active';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.green, AppColors.gold],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              const Text(
                'UBUNTUID DIGITAL IDENTITY',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: active ? 0.25 : 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: QrImageView(
                data: 'UBUNTUID:$idNumber',
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            fullName.isEmpty ? 'Unknown' : fullName,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(idNumber, style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 2)),
          const SizedBox(height: 4),
          Text('DOB: $dateOfBirth', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 20),
          const Text(
            'Present this QR code to a department official or approved organisation for identity verification.',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
