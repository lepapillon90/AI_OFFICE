import 'package:flutter/material.dart';

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

  /// Color used to represent this status on NPC labels and the computer popup.
  Color get displayColor {
    switch (this) {
      case NpcStatus.idle:
        return const Color(0xFF9E9E9E);
      case NpcStatus.working:
        return const Color(0xFF4CAF50);
      case NpcStatus.meeting:
        return const Color(0xFFFFC107);
      case NpcStatus.error:
        return const Color(0xFFF44336);
      case NpcStatus.offline:
        return const Color(0xFF616161);
    }
  }
}
