import 'package:digital_id/features/admin/domain/user_list_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserListItem.roleLabel', () {
    for (final entry in {
      AdminUserRole.citizen: 'Citizen',
      AdminUserRole.departmentOfficial: 'Department Official',
      AdminUserRole.organisationUser: 'Organisation User',
      AdminUserRole.administrator: 'Administrator',
    }.entries) {
      test('${entry.key} labels as "${entry.value}"', () {
        final item = UserListItem(
          userId: 'id',
          displayName: 'name',
          email: 'a@b.com',
          role: entry.key,
          active: true,
          createdAt: DateTime(2024, 1, 1),
        );
        expect(item.roleLabel, entry.value);
      });
    }
  });
}
