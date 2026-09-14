# Phase 8 (착수) — 파일 업로드/공유

채팅에서 실제 파일(문서, 이미지 등)을 첨부해 공유할 수 있습니다. `docs/PHASE6_AI_EMPLOYEES.md`의 `npc-documents`(AI 직원이 만든 가상 문서)와는 별개로, 사용자가 자기 컴퓨터에서 직접 고른 실제 파일을 다루는 기능입니다.

- 채팅 입력창 옆 📎(첨부) 아이콘으로 브라우저 파일 선택창을 열고, 고른 파일을 업로드해 현재 보고 있는 대화(공간 채팅 / 귓속말 / AI 직원 방)로 전송
- 최대 20MB — UI 단의 안내용 상한이며, 서버 쪽 진짜 제한은 Storage 버킷/정책 설정에 따릅니다
- 메시지 목록에 파일명이 클릭 가능한 칩으로 표시되고, 클릭하면 서명된 URL을 새 탭으로 엶

## 필요한 설정 — DB 컬럼 + Storage 버킷

`docs/PHASE5_MULTIPLAYER.md`의 `messages` 테이블에 첨부 파일 컬럼을 추가하고, 파일을 저장할 `chat-attachments` Storage 버킷을 만들어야 합니다. Supabase 대시보드 **Storage**에서 `chat-attachments`라는 이름으로 **비공개(private)** 버킷을 하나 만든 뒤(또는 아래 SQL의 `insert into storage.buckets`로 대신 만들어도 됨), SQL Editor에서 아래를 실행해주세요 (몇 번을 다시 실행해도 안전합니다).

```sql
alter table messages add column if not exists attachment_path text;
alter table messages add column if not exists attachment_name text;

insert into storage.buckets (id, name, public)
values ('chat-attachments', 'chat-attachments', false)
on conflict (id) do nothing;

drop policy if exists "members_read_chat_attachments" on storage.objects;
drop policy if exists "members_write_chat_attachments" on storage.objects;

-- Files are stored at "<companyId>/<epoch-micros>-<fileName>", so the
-- first path segment is the company id these policies check membership of.
create policy "members_read_chat_attachments" on storage.objects
  for select using (
    bucket_id = 'chat-attachments'
    and exists (
      select 1 from company_members m
      where m.user_id = auth.uid()
        and m.company_id::text = (storage.foldername(name))[1]
    )
  );
create policy "members_write_chat_attachments" on storage.objects
  for insert with check (
    bucket_id = 'chat-attachments'
    and exists (
      select 1 from company_members m
      where m.user_id = auth.uid()
        and m.company_id::text = (storage.foldername(name))[1]
    )
  );

notify pgrst, 'reload schema';
```

실행 전에는 첨부 시도 시 업로드가 조용히 실패하고(파일이 전송되지 않음), 텍스트 채팅 자체는 계속 정상 동작합니다.

## 앱 동작

1. 📎 버튼 → `lib/util/pick_file.dart`(웹 전용 `dart:html` 파일 선택창, `flutter test`의 VM에서는 항상 null을 반환해 안전하게 컴파일됨)로 파일을 고름
2. `OfficeGame.sendChatAttachment()`가 `uploadChatAttachment` 콜백(`ChatAttachmentRepository.upload`)으로 업로드하고, 성공하면 `attachmentPath`/`attachmentName`을 실은 `ChatMessage`를 평소 `sendChatMessage`와 같은 방식(공개/귓속말/AI 방 라우팅)으로 내보냄
3. **AI 직원 방에 첨부해도 실제 명령으로 해석되지 않음**: 메시지 본문을 일부러 `@이름`만(뒤에 아무 텍스트 없이) 채워서 보내 `_parseMention`의 `command`가 항상 빈 문자열이 되도록 함 — AI 직원이 첨부파일 내용을 실제로 읽지는 못하므로, 방을 공유하되 명령 디스패치(및 그로 인한 불필요한 API 호출)는 막음
4. 메시지 목록에서 `attachmentName`이 있으면 일반 텍스트 대신 클릭 가능한 파일 칩을 렌더링 — 클릭 시 `OfficeGame.attachmentUrlFor()`가 `resolveAttachmentUrl` 콜백(`ChatAttachmentRepository.signedUrl`)으로 서명 URL을 받아 새 탭으로 엶(`lib/util/open_url.dart`)
5. `messages` 테이블에 `attachment_path`/`attachment_name`으로 함께 저장되어, 재로그인 후에도 파일 링크가 그대로 남음

## 자동 테스트

`test/chat_attachment_test.dart` — 업로드 성공/실패/미설정 시 동작, AI 직원 방에 보내도 명령이 디스패치되지 않는 것, `attachmentUrlFor`의 해석/미설정/무첨부 케이스를 `OfficeGame` 레벨에서 검증. 실제 브라우저 파일 선택창(`dart:html`)은 `flutter test`의 VM에서 재현할 수 없어 이 경로는 테스트로 커버하지 않음 — 실제 브라우저에서 직접 확인 필요.

## 이연된 범위

- AI 직원이 첨부 파일의 실제 내용을 읽고 반응하는 기능(예: 업로드된 PDF를 요약)은 이번 범위 아님 — 지금은 "같은 방에 공유"만 됨
- 이미지 미리보기(썸네일)는 없음 — 모든 첨부가 파일명 칩으로만 표시되고, 열어야 내용을 볼 수 있음
- 업무 보드 카드에 파일 첨부는 이번 범위 아님 — 채팅에서만 가능
