import 'package:ai_office/data/company_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only owner can manage roster and edit AI employees is a subset of '
      'canManageRoster', () {
    expect(CompanyRole.owner.canManageRoster, isTrue);
    expect(CompanyRole.hrManager.canManageRoster, isTrue);
    expect(CompanyRole.member.canManageRoster, isFalse);
  });

  test('only owner can manage members (admin screen / role changes)', () {
    expect(CompanyRole.owner.canManageMembers, isTrue);
    expect(CompanyRole.hrManager.canManageMembers, isFalse);
    expect(CompanyRole.member.canManageMembers, isFalse);
  });

  test('dbValue/fromDb round-trip for every role', () {
    for (final role in CompanyRole.values) {
      expect(CompanyRole.fromDb(role.dbValue), role);
    }
  });

  test('fromDb defaults unknown values to member', () {
    expect(CompanyRole.fromDb('something_unexpected'), CompanyRole.member);
  });

  test('displayLabel is set for every role', () {
    expect(CompanyRole.owner.displayLabel, '대표');
    expect(CompanyRole.hrManager.displayLabel, '인사관리자');
    expect(CompanyRole.member.displayLabel, '일반 직원');
  });
}
