import 'package:digital_id/models/user_role.dart';
import 'package:digital_id/routing/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRoutes.dashboardForRole', () {
    test('maps every role to its own dashboard, never a shared or wrong one', () {
      const expected = {
        UserRole.citizen: AppRoutes.citizenDashboard,
        UserRole.departmentOfficial: AppRoutes.departmentDashboard,
        UserRole.organisationUser: AppRoutes.organisationDashboard,
        UserRole.administrator: AppRoutes.adminDashboard,
      };

      for (final entry in expected.entries) {
        expect(AppRoutes.dashboardForRole(entry.key), entry.value);
      }

      // Every mapped destination must be distinct -- if two roles ever
      // mapped to the same dashboard route, the role-based access guard in
      // app_router.dart would let one role silently see another's screen.
      final destinations = expected.values.toSet();
      expect(destinations.length, UserRole.values.length);
    });
  });
}
