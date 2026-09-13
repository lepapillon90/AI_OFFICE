enum NpcStatus {
  idle,
  working,
  meeting,
  error,
  offline,
}

extension NpcStatusDisplay on NpcStatus {
  String get displayLabel {
    switch (this) {
      case NpcStatus.idle:
        return '대기 중';
      case NpcStatus.working:
        return '작업 중';
      case NpcStatus.meeting:
        return '회의 중';
      case NpcStatus.error:
        return '오류';
      case NpcStatus.offline:
        return '퇴근';
    }
  }
}
