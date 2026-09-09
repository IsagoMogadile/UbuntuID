import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_routes.dart';
import '../../verification/presentation/verification_request_list_view.dart';

class DepartmentVerificationListScreen extends StatelessWidget {
  const DepartmentVerificationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification Requests')),
      body: VerificationRequestListView(
        onOpen: (id) => context.push('${AppRoutes.departmentVerification}/$id'),
      ),
    );
  }
}
