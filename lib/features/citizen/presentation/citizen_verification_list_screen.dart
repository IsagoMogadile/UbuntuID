import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_routes.dart';
import '../../verification/presentation/verification_request_list_view.dart';
/// Technical Author: TechMinions : A citizen's own verification history -- which organisations have requested to verify their identity/credentials, and the outcome. Reuses the same shared list view as the department official/organisation/admin verification screens (`lib/features/verification/`); a citizen never approves/rejects, they only view.
/// A citizen's own verification history -- which organisations have
/// requested to verify their identity/credentials, and the outcome. Reuses
/// the same shared list view as the department official/organisation/admin
/// verification screens (`lib/features/verification/`); a citizen never
/// approves/rejects, they only view.
class CitizenVerificationListScreen extends StatelessWidget {
  const CitizenVerificationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification Requests')),
      body: VerificationRequestListView(
        onOpen: (id) => context.push('${AppRoutes.citizenVerification}/$id'),
      ),
    );
  }
}
