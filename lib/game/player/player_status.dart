import 'package:flutter/material.dart';

enum PlayerStatus {
  office,
  remote,
  away,
  busy,
}

extension PlayerStatusDisplay on PlayerStatus {
  String get displayLabel {
    switch (this) {
      case PlayerStatus.office:
        return '출근';
      case PlayerStatus.remote:
        return '재택';
      case PlayerStatus.away:
        return '자리비움';
      case PlayerStatus.busy:
        return '다른 업무 중';
    }
  }

  Color get displayColor {
    switch (this) {
      case PlayerStatus.office:
        return const Color(0xFF4CAF50);
      case PlayerStatus.remote:
        return const Color(0xFF2196F3);
      case PlayerStatus.away:
        return const Color(0xFF9E9E9E);
      case PlayerStatus.busy:
        return const Color(0xFFF44336);
    }
  }
}
