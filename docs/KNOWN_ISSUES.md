# 알려진 이슈

## flutter analyze / LSP 분석 서버 통신 오류

- **증상**: `flutter analyze` 실행 시 analysis server가 `FormatException: Unterminated string`과 함께 종료 코드 255로 죽는다. `dart analyze`는 정상 동작한다.
- **원인**: 프로젝트 경로에 한글(비-ASCII) 문자가 포함되어 있음
  (`C:\Users\suhye\OneDrive\바탕 화면\AI오피스\...` — "바탕 화면", "AI오피스").
  LSP는 `Content-Length` 헤더를 바이트 수로 명시하는데, UTF-8에서 한글은 문자당 3바이트를 차지한다.
  Windows에서 dart `analysis_server`의 `LspByteStreamServerChannel`이 바이트 길이와 문자 길이 처리에서 어긋나면서
  워크스페이스 경로(rootUri)가 포함된 JSON 메시지가 중간에 잘려 전달되고, `jsonDecode`가 실패해 서버가 죽는다.
- **재현 방법**: 한글/공백이 섞인 경로에서 `flutter analyze` 실행.
- **해결 방향 (추후 진행)**: 프로젝트를 영문/숫자만 있는 경로(예: `C:\dev\ai-office`)로 이동한 뒤 재검증.
  - 코드 자체의 문제가 아니라 Windows + 한글 경로 조합에서 발생하는 환경 이슈.
- **확인 일자**: 2026-09-13
