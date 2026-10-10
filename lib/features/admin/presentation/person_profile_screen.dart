import 'package:flutter/material.dart';

import 'digital_profile_view.dart';

/// A person's full digital profile, opened by SA ID number -- from an
/// organisation's staff list, or anywhere else an administrator has an ID
/// number but no user row to open.
class PersonProfileScreen extends StatelessWidget {
  const PersonProfileScreen({super.key, required this.idNumber});

  final String idNumber;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Digital profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [DigitalProfileView(idNumber: idNumber)],
      ),
    );
  }
}
