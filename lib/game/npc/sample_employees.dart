import 'package:ai_office/game/npc/ai_employee.dart';
import 'package:ai_office/game/npc/npc_status.dart';
import 'package:ai_office/game/npc/workstation.dart';

/// Placeholder AI employee roster used until Supabase-backed data arrives.
final List<AiEmployee> sampleEmployees = [
  AiEmployee(
    id: 'ai-1',
    name: '리아',
    role: '백엔드 개발자',
    provider: 'anthropic',
    workstationId: Workstation.all[0].id,
    status: NpcStatus.working,
  ),
  AiEmployee(
    id: 'ai-2',
    name: '노아',
    role: '프론트엔드 개발자',
    provider: 'anthropic',
    workstationId: Workstation.all[1].id,
    status: NpcStatus.meeting,
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
    status: NpcStatus.working,
  ),
];
