/// A user's role within a company. Only [owner] and [hrManager] may manage
/// the AI employee roster.
enum CompanyRole {
  owner,
  hrManager,
  member;

  static CompanyRole fromDb(String value) {
    switch (value) {
      case 'owner':
        return CompanyRole.owner;
      case 'hr_manager':
        return CompanyRole.hrManager;
      default:
        return CompanyRole.member;
    }
  }

  String get dbValue {
    switch (this) {
      case CompanyRole.owner:
        return 'owner';
      case CompanyRole.hrManager:
        return 'hr_manager';
      case CompanyRole.member:
        return 'member';
    }
  }

  bool get canManageRoster =>
      this == CompanyRole.owner || this == CompanyRole.hrManager;

  /// Only the owner can see the admin screen (member list/role changes) or
  /// grant the hr_manager role to someone else — hardening against an
  /// hr_manager escalating another account (or themselves) to hr_manager.
  bool get canManageMembers => this == CompanyRole.owner;

  String get displayLabel => switch (this) {
        CompanyRole.owner => '대표',
        CompanyRole.hrManager => '인사관리자',
        CompanyRole.member => '일반 직원',
      };
}
