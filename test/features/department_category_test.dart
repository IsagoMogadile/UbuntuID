import 'package:digital_id/features/department_official/domain/department_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DepartmentCategory.fromName', () {
    for (final entry in {
      'Department of Home Affairs': DepartmentCategory.homeAffairs,
      'SASSA': DepartmentCategory.sassa,
      'South African Social Security Agency': DepartmentCategory.sassa,
      'Department of Basic Education': DepartmentCategory.basicEducation,
      'Department of Higher Education and Training': DepartmentCategory.higherEducation,
      'South African Police Service': DepartmentCategory.saps,
      'SAPS': DepartmentCategory.saps,
      'SARS': DepartmentCategory.other,
      'Department of Transport': DepartmentCategory.other,
      null: DepartmentCategory.other,
    }.entries) {
      test('"${entry.key}" classifies as ${entry.value}', () {
        expect(DepartmentCategory.fromName(entry.key), entry.value);
      });
    }

    test('Basic and Higher Education never collide, even though one name contains the other',
        () {
      expect(
        DepartmentCategory.fromName('Department of Higher Education and Training'),
        DepartmentCategory.higherEducation,
      );
      expect(
        DepartmentCategory.fromName('Department of Basic Education'),
        DepartmentCategory.basicEducation,
      );
    });
  });
}
