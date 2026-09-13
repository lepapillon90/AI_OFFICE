# Codex 자율 개발 루프

이 저장소는 대화를 이어 붙이지 않고, 매 바퀴마다 새 `codex exec` 세션을 시작하는 자율 개발 루프와 Flutter Web 기반 AI 오피스 데모를 포함합니다.

## Phase 1 가상 오피스

Flutter Web + Flame으로 만든 단일 사용자 픽셀 오피스 데모입니다.

- WASD 또는 방향키로 캐릭터 이동
- 카메라 추적
- 벽·책상 충돌
- 바닥·벽·책상·의자·소파·화분 등 픽셀 오브젝트

실행 방법:

```powershell
flutter pub get
flutter run -d chrome
```

Chrome이 Flutter 기기 목록에 없으면 `flutter run -d edge`를 사용합니다.

## 구성 파일

- `loop/loop.ps1` — Windows 루프 본체
- `loop/env.sh` — 모델, 최대 턴, 대기 시간, 최대 바퀴 설정
- `loop/PROMPT.md` — 각 새 Codex 세션이 읽는 지시서 틀
- `loop/runner.ps1` — 예약 작업용 실행기; Codex 위치와 PATH를 명시적으로 설정
- `loop/control.ps1` — 예약 작업 설치·켜기·끄기·상태 확인·삭제
- `docs/DESIGN.md` — Phase 1 기획서
- `docs/STATUS.md` — 진행 상황과 다음 작업
- `docs/feedback/INBOX.md` — 사용자 지시 수신함 틀
- `logs/` — 날짜별 실행 로그 (Git 제외)
- `loop/STOP` — 만들면 현재 바퀴가 끝난 뒤 정상 종료

## 설정

`loop/env.sh`에서 값을 수정합니다. `MODEL`을 비워 두면 Codex CLI의 기본 모델을 사용합니다. `MAX_RUNS=0`은 무한 반복입니다.

## 예약 작업 제어

PowerShell에서 저장소 루트를 기준으로 실행합니다.

```powershell
# 로그인 시 실행되도록 등록하지만, 즉시 실행되지는 않음
.\loop\control.ps1 install

# 켜기
.\loop\control.ps1 enable

# 끄기 (현재 실행 중인 작업도 중지)
.\loop\control.ps1 disable

# 상태 보기
.\loop\control.ps1 status

# 등록 삭제
.\loop\control.ps1 uninstall
```

작업 스케줄러 접근이 제한된 환경에서는 위 명령을 **관리자 PowerShell**에서 실행합니다.

예약 작업은 로그인 시 시작하며, 오류로 종료되면 1분 간격으로 재시작합니다. `STOP`에 의한 정상 종료는 재시작하지 않습니다.

## 수동 실행

```powershell
.\loop\loop.ps1
```

멈추려면 `loop/STOP` 파일을 만들고 현재 바퀴가 끝날 때까지 기다립니다.
