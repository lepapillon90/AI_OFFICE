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
}
