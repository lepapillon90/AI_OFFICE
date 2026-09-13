enum Floor {
  lobby,
  workspace,
  projectRoom,
  executive,
}

extension FloorInfo on Floor {
  /// The floor number shown to the user (1~4).
  int get level {
    switch (this) {
      case Floor.lobby:
        return 1;
      case Floor.workspace:
        return 2;
      case Floor.projectRoom:
        return 3;
      case Floor.executive:
        return 4;
    }
  }

  String get displayName {
    switch (this) {
      case Floor.lobby:
        return '로비·카페';
      case Floor.workspace:
        return '업무공간·서버실';
      case Floor.projectRoom:
        return '프로젝트룸';
      case Floor.executive:
        return '대표실';
    }
  }

  static final List<Floor> ordered = [
    Floor.lobby,
    Floor.workspace,
    Floor.projectRoom,
    Floor.executive,
  ];
}
