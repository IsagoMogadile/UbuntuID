import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_routes.dart';
import '../../verification/presentation/verification_request_list_view.dart';

class AdminVerificationQueueScreen extends StatelessWidget {
  const AdminVerificationQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification Queue')),
      body: VerificationRequestListView(
        onOpen: (id) => context.push('${AppRoutes.adminVerification}/$id'),
      ),
    );
  }
}
