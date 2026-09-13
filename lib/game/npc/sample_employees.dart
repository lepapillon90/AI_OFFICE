import 'package:ai_office/game/npc/ai_employee.dart';
import 'package:ai_office/game/npc/npc_status.dart';
import 'package:ai_office/game/npc/workstation.dart';

/// Placeholder AI employee roster used until Supabase-backed data arrives.
///
/// Everyone starts 대기 중 (idle) — status now genuinely reflects activity
/// (it flips to 작업 중 while handling an `@employee` chat command and
/// back down once it's done, see OfficeGame._dispatchNpcCommand), so a
/// hardcoded "working"/"meeting" here would be misleading rather than
/// decorative.
final List<AiEmployee> sampleEmployees = [
  AiEmployee(
    id: 'ai-1',
    name: '리아',
    role: '백엔드 개발자',
    provider: 'anthropic',
    workstationId: Workstation.all[0].id,
    status: NpcStatus.idle,
  ),
  AiEmployee(
    id: 'ai-2',
    name: '노아',
    role: '프론트엔드 개발자',
    provider: 'anthropic',
    workstationId: Workstation.all[1].id,
    status: NpcStatus.idle,
  ),
  AiEmployee(
    id: 'ai-3',
    name: '유나',
    role: 'QA 엔지니어',
    provider: 'anthropic',
    workstationId: Workstation.all[2].id,
    status: NpcStatus.idle,
  ),
  AiEmployee(
    id: 'ai-4',
    name: '하나',
    role: '인사관리자',
    provider: 'anthropic',
    workstationId: Workstation.all[3].id,
    status: NpcStatus.idle,
  ),
  // 3층 프로젝트룸 — 공용 프로젝트 테이블 두 자리.
  AiEmployee(
    id: 'ai-5',
    name: '도윤',
    role: 'PM/기획자',
    provider: 'openai',
    workstationId: 'project-desk-1',
    status: NpcStatus.idle,
  ),
  AiEmployee(
    id: 'ai-6',
    name: '하윤',
    role: '프로덕트 디자이너',
    provider: 'openai',
    workstationId: 'project-desk-2',
    status: NpcStatus.idle,
  ),
  // 4층 대표실엔 일부러 AI 직원을 두지 않음 — 대표는 실제 사용자 본인.
];
