# Phase 1 실행 안내

## 목표

브라우저에서 한 명의 캐릭터가 픽셀 오피스 안을 이동하는 데모입니다.

## 실행

```powershell
flutter pub get
flutter run -d chrome
```

Chrome이 Flutter 기기로 감지되지 않으면 아래 명령을 사용합니다.

```powershell
flutter run -d edge
```

## 조작

- 이동: `W`, `A`, `S`, `D` 또는 방향키
- 벽과 책상은 통과할 수 없습니다.

## 현재 제외된 기능

로그인, 멀티플레이, 채팅, NPC 상호작용, Supabase, AI 직원은 이후 단계 범위입니다.
