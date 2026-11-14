# FocusOne memory

## 배포
- GitHub Actions 산출물은 서명·공증이 없어 macOS Gatekeeper가 차단 → CI에서 ad-hoc 서명(`codesign -s -`)만 하고, 사용자는 `xattr -cr` 로 격리 해제. 공증은 Apple Developer $99/년이라 보류.
- 이 맥에는 소스가 있으므로 로컬 빌드(`flutter build macos --release`)가 정답 — 격리 속성이 아예 안 붙음.

## Android 출시 계정 (2026-10-13)
- Play **조직 계정**(develop@looinlabs.com, Google Workspace 사용자)으로 새로 가입해 출시. 개인 계정(2001kmin, 개발자명 LooinLabs, 하루전 운영 중)은 2023-11 이후 규정상 새 앱마다 테스터 12명×14일 비공개 테스트 필요 → 사용자가 조직 계정 선택.
- 주소: 조직 계정은 사업장 주소 공개. 사업장=자택이지만 하루전(인앱 구매)에 이미 공개돼 있어 비상주 사무실 안 함.
- D-U-N-S: 2026-10-16 발급 거절됨(영문 사업자등록증 미제출). '해결(Resolved)'은 발급이 아니라 처리 종료라는 뜻, 본문 끝까지 읽을 것. 이전 기록: Apple duns-lookup(무료)으로 사용자 제출 완료 2026-10-13. 발급(1~2주) 후 Play 조직 가입($25·인증 사용자) → 서비스 계정 API 키 ~/.config/fokko/.
- 출시 AAB 서명: android/key.properties(gitignore)가 ~/.config/focusone 키를 가리켜야 함. 없으면 debug 키로 조용히 서명됨.

## 디자인 v2 (2026-10-08 사용자 확정 → main 머지) — 현재 디자인 원본
- 주 레퍼런스 Tiimo 집중 화면(Mobbin) — 사용자가 A안 선택. **링 안에 장면 일러스트**(숲/달토끼/고래)를 넣는 게 사용자 요구 — 사운드 장면이 강점.
- 설계서: astra(`docs/v2/app-design-spec.md`), 변경 근거 `docs/v2/app-deviations.md`. 바탕화면 시안 3종(.dc.html)은 v1 원본 — v2가 대체함.
- 시간 글자는 링 밖(아래). 링 안 글자 없으니 SceneDialPainter 베일 제거.
- 미리보기 PNG: `flutter test tool/preview --dart-define=OUT=<dir>` (macOS AppleGothic·MaterialIcons 로드). 탭 전환 캡처는 AnimatedSwitcher 첫 프레임이 opacity 0이라 pump 2번 더 필요.
- 비선택 작업 체크 = `completeTask(id)` — 타이머·현재 작업 보존(selectTask 경유 금지).

## 모바일 v1 (2026-10-11, mobile-v1 브랜치)
- 레퍼런스: App Store "Arctic Habit"(iPhone 미러링 실측, docs/mobile/refs). 레이아웃 패턴만 참고, 콘셉트·문구·그림은 자체 — 심사 4.1(카피캣) 대응. 사용자 지적으로 GitHub식 잔디 → 장면색 집중 달력으로 교체.
- 구조: `lib/mobile/`(셸·탭 4개), `main.dart`에서 iOS/Android 분기. 데스크탑 전용 서비스 호출 금지. 폰은 `autoBreak=false`(휴식은 보상 시트에서 선택).
- 타이머는 시각 기준(package:clock) + 진행 세션(ActiveSession) 저장 → 재실행 이어가기, 세션 ID로 기록·보상 1회. 실집중 구간(segments) 저장해 통계가 일시정지·복구에 왜곡되지 않음.
- 앱 잠금: iOS Family Controls(FocusLock.swift + FocusMonitor 확장, App Group group.com.looinlabs.focusone, DeviceActivity 최소 15분 → 15분 이상 세션만), Android 접근성 서비스(패키지명만, 만료 후 미차단). 배포용 Family Controls 권한 신청 2026-10-11 — 승인 전엔 App Store/TestFlight 서명 불가.
- 그림: Higgsfield 크레딧 소진 → codex 내장 이미지 생성(무료)으로 친구 12·장식 9. 소리: tool/gen_sounds.py 합성(장면 3 + 상황 5 + 소음 3).
- 리뷰: astra 리뷰 1(12건) 반영 기록 docs/mobile/review-1.md.
- Android 업로드 키: `~/.config/focusone/upload-keystore.jks` + key.properties (저장소 밖, 분실 시 Play 업로드 키 재설정 필요 → 백업 필수).

## 게임화 (2026-11-04)
- 동기: 실사용 인기 없음 → 자랑 욕구. 숫자 레벨 금지, 호칭으로 (사용자 요구).
- 칭호 = 끝까지 완료한 집중 누적 분(`AppState.focusMinutesTotal`) — 탈출로 안 내려감. 문턱은 Fable 제안의 절반(사용자 '마스터 더 빨리'): 0·30·150·450·1200·2400·4800·9000·15000·30000분. 단일 소스 `lib/models/focus_title.dart`.
- 서버는 칭호를 안 받는다(위조 방지). `ranking()`이 `total_minutes = sum(gained)`(하루 720 상한 거친 값)만 주고 앱이 같은 문턱으로 계산 → 전당 칭호 ≤ 로컬 칭호일 수 있음(안내문 있음).
- 지난 주/달 1~3위는 `hall_of_fame`에 지연 스냅샷(첫 조회자가 저장, 크론 없음). 동점은 먼저 갱신한 사람(row_number, updated_at).
- 아바타 = 데려올 친구 id (새 선택 UI 없음).
- 음원: ffmpeg `alimiter`는 lookahead만큼 지연 → `latency=1` 필수(안 하면 반복마다 5ms 무음).

## 앱 아이콘 v2 (2026-10-11) — 현재
- 사용자 선택: "네 친구 빼꼼" F3-b — 숲·밤·바다·일상 친구(새싹사슴·달토끼·물결고래·갈색 라떼멍) 얼굴이 네 색 링 아래로 빼꼼. 앱 안 캐릭터와 같은 스타일이어야 한다는 사용자 지적으로 H3(실사풍 고래) 교체.
- 원본 `assets/icon/source.png`(1024 불투명) → `python3 tool/make_icons.py` 가 iOS·macOS·Windows·Linux·트레이·Android 전부 생성.
- 과정: 고래 A·사슴·달토끼·라떼멍·네 친구 비교 → "부담스럽다" 피드백(큰 눈·꽉 찬 구성) → 작게·눈웃음·여백 → 빼꼼 + 얼굴 1.5배.

## 앱 아이콘 v1 (2026-10-08)
- 사용자 선택: Higgsfield 시안 H3(바다·고래, gpt_image_2_5, job 7dc1b3a0…). 기록 `docs/v2/higgsfield-log.md`.
- 생성 이미지의 회색 배경은 크레딧 대신 PIL로 스퀘어클(n=5) 마스크 처리 → macOS 1024(본체 824+여백 100+그림자), Windows .ico·Linux 256·트레이는 여백 없는 타일.
- 플랫폼 폴더는 커밋 안 하므로 `flutter create` 후 `bash tool/apply_icons.sh` 필수 (CI에도 단계 추가). 트레이 아이콘은 pubspec assets 등록 필요.

## 디자인 원본 v1 (2026-07-14)
- **디자인의 단일 원본은 바탕화면의 시안 3종**: `~/Desktop/FocusOne Forest v3.dc.html`, `FocusOne Night.dc.html`, `FocusOne Ocean.dc.html`. 색·크기·문구 전부 여기서 추출해 `SceneStyle`(design_tokens.dart)에 옮겼다 — 임의 변경 금지.
- 다이얼 안 풍경(숲/달토끼/고래)은 `SceneDialPainter`(core/scene_decorations.dart)가 지름 비율 좌표로 그린다 (88px 미니/216px 확장 공용).
- 시안에 없어서 추가한 최소 기능: 미니 우하단 패널 열기 아이콘, 헤더 접기 아이콘, 세션 라벨 탭→길이 메뉴, 섹션 헤더의 인박스/차단 전환, 리스트 하단 할 일 입력. 뱃지 탭 = 모드 순환.
- 시안의 배경 풍경(나무들/유성/고래 유영)은 쇼케이스 배경이지 앱 창이 아님 — 구현 대상 아님.
- 패널 560px 고정이라 인박스/차단 뷰에서는 216px 다이얼을 소형 타이머 줄(`_CompactTimerStrip`)로 접는다 — 내용 공간 확보용, 사용자 요청(2026-07-14 편의성 개선).
- 카드가 배경색을 직접 칠하므로 ListTile/잉크 쓰는 내부에는 `Material(type: transparency)` 필요.

## 장면 모드 (2026-07-14)
- `FocusScene` enum(core/design_tokens.dart)이 단일 소스: 테마 색 + 아이콘 + 사운드 경로를 enum 멤버로 보유. 라이트/다크 시스템 테마는 제거하고 장면이 테마를 결정.
- 앰비언트 사운드는 저작권 없는 파일 확보 대신 Python stdlib로 합성 — 재생성: `python3 tool/gen_sounds.py assets/sounds` (40초 루프, 경계 크로스페이드). 재생은 audioplayers, **집중 중(focus+running)에만** 루프 — 대기/휴식/일시정지 시 정지.
- 사운드 on/off·볼륨은 확장 패널 헤더의 스피커 팝업에서 조절, StoreData에 저장 (기본 on/0.6). 슬라이더 드래그 중엔 persist:false — 파일 쓰기 폭주 방지.
- 위젯 테스트는 Ahem 폰트(글자당 1em)라 실제보다 텍스트가 훨씬 넓다 — 헤더처럼 좁은 Row의 Text엔 maxLines/Flexible 필수 (2026-07-14 오버플로 원인).
- audioplayers 때문에 Linux CI에 gstreamer dev 패키지, .deb Depends에 gstreamer 런타임 추가됨.

- 2026-10-11 폰 집중 강제: 일시정지 없음, 그만두기는 시작 10초 안 취소만. 실수 출구는 물방울 비상 탈출(남은 1분당 2개 = 모은 속도의 2배라 아깝게, 결과는 그만두기와 같아 보상 없음). '시간 단축'은 보상을 사는 셈이라 기각.
- 2026-10-11 랭킹: Supabase 프로젝트 focusone(ref bvnwdbbjkrjdqgqyidhp, 서울, DB 비번 ~/.config/focusone/). 익명 로그인 + 닉네임 옵트인. 테이블 RLS 정책 없음 → security definer 함수(submit_score/ranking/leave_ranking)로만. 점수는 앱 rankScore(모은 물방울 − 비상 탈출, 상점 구매는 유지)를 보내고 서버가 차이만 반영: 하루(KST) +720(사용자 결정 12시간), 직전 제출 뒤 경과 분 이상 못 오름. 주간 = 월요일 KST 시작.

- 2026-10-12 앱 이름 FocusOne → **Tocko** (같은 분야 'Focus One' 앱 다수, 스토어 검색·상표 충돌 회피). 보이는 이름만 변경 — 번들 ID com.looinlabs.focusone·패키지·저장소·Supabase 프로젝트명은 유지(Family Controls 승인이 번들 ID에 묶임). 후보 비교: Focusling(길다), Onlee(타이머 느낌 없음), Fokko.
- 2026-10-12 앱 이름 최종 **Fokko** (Tocko에서 변경, 사용자 결정). 스토어 'Fokko: ADHD 집중 타이머 & 앱 잠금', 사이트 looinlabs.com/fokko, Android com.looinlabs.fokko, ASC 키 ~/.config/fokko/.
- 2026-10-17 스토어 에셋은 Windows에서도 생성: flutter test로 실제 MobileShell을 기기 크기로 렌더(tool/store, 폰트 Pretendard+Noto Color Emoji를 FONTS로). 영상도 프레임 렌더 → ffmpeg. 함정: CustomPainter의 TextPainter는 테마 글꼴을 상속 안 함(테스트에선 □) → records 막대 라벨에 DefaultTextStyle 전달. 시드는 ID가 마이크로초 시각이라 Windows에선 연달아 만들면 태그 ID가 겹침.

## 2026-11-05 1:1 대결·카톡 초대
- 대결 = 이번 주(월~일 KST) `daily_points.gained` 합. points(물방울−비상 탈출) 대신 gained: "집중 시간 대결"이라 감점 제외.
- 친구 식별자는 상대 초대 코드(6자, 0·O·1·I 제외). user_id는 앱에 안 보냄. 대결엔 명예의 전당 참여(닉네임)가 필요 — 친구 목록에 닉네임이 있어야 해서.
- 카톡: 사용자 선택 = 카카오 SDK 메시지 카드. 키 전엔 공유 시트 폴백(코드+App Store id6821653231 링크). 카톡 버튼 executionParams invite=<코드> → receiveKakaoScheme → pendingInvite → 셸이 집중 끝난 뒤 DuelPage(initialCode).
- 꾸미기 보관함·도감·상점: 사용자 선택 = 탭바 바로 위 고정.

## 2026-11-06 v3 성장 (growth-v3)
- 집중 중: 링도 0에서 차오름(배경과 방향 통일, 사용자 지적). 친구 점점 선명해짐은 유지 — 사용자 "선명해지긴 해야돼". 링 안쪽은 불투명 바탕으로 차오르는 색 차단.
- 장면 표현은 사용자가 직접 정함: 숲 = 물들며 자라 덮임, 밤 = 해질녘→우주(경계선 없음, 시작이 어두우면 변화가 안 보임), 일상 = 아이스 아메리카노+출렁임, 빨대 없음.
- 성장 데이터는 Progress.growth 한 덩어리, XP·칭호는 세션에서 파생. 보상 키 'daily:<날짜>'·'weekly:<월요일>'로 중복 방지.
- 순서 함정: 빠진 날 얼음 판단을 보상 지급보다 먼저. 안 그러면 주간 보상 얼음이 지난 공백에 소급 사용됨. 진행 중 세션이 있으면 판단을 미룸(자정 넘겨 복귀 시 얼음 낭비 방지).
- UI 방향: 사용자가 입체·젤리·Jua 글꼴을 모두 거절, "처음 디자인 느낌이 좋아", 불꽃 색도 별로. 듀오링고는 구조만 따르고 겉모습은 출시 디자인 유지. 새 화면도 기존 카드·PillButton·RoundIconButton·장면 accent로 만든다.
- 3단계: 보상은 달성 순간 확정 지급, 상자는 unopened 키만 지우는 연출. 칸·칭호·친구 단계·업적은 저장 안 하고 기록에서 계산.
- 테스트 함정: testWidgets 안(가짜 시간)에서 시작한 저장을 runAsync로 기다리면 영원히 안 끝남 → 저장 파일에 상태를 넣고 init으로 시작.
- Semantics 라벨이 옆 글자와 합쳐지면 낭독기·bySemanticsLabel에서 안 보임 → 눌리는 항목엔 container: true.
- 4단계: 리그 점수는 verified_daily만(서버 시계). 구 daily_points·submit_score와 섞지 않음. 서버는 실제 집중을 증명 못 함: 시작~예정 종료가 지났다는 것만 안다. 크론 없이 조회·제출 때 지연 정산.
- 접근성 함정: Semantics(excludeSemantics: true)는 자식 GestureDetector의 누르기 동작까지 가린다 → 같은 Semantics에 onTap을 직접 넘긴다. test/accessibility_test.dart가 '버튼인데 누르기 없음'을 잡는다.

## v3 레벨·친구 결정 (2026-11-06)
- 레벨 = 지도 칸 번호. 간격 25분에서 칸마다 15분씩 증가, 칭호 문턱은 가장 가까운 칸을 대체(63칸). 기록에서 계산해 이행 불필요. 사용자: "단계가 너무 많고 물방울만 있어 동기가 안 생김".
- 기본 친구(해금 0분)는 캐릭터당 1명 고정. ownedCount가 항상 1을 돌려주고 저장값은 안 바꾼다. 처음엔 +1로 만들었으나 사용자가 2개로 보이는 걸 지적함. 수집 재미는 나중에 친구를 36종으로 늘려 채운다. 해금 조건을 올려도 이미 보유한 친구는 isUnlocked 유지.
- 차오름 overshoot는 물결 폭만큼만. 크게 잡으면 시작이 늦고 끝나기 전에 가득 찬다(사용자가 10분 타이머에서 약 1분 지연으로 발견).
- 친구 36종, 해금은 장면 누적 0~1500분(9단계) 또는 전체 6000분. 사용자가 '100시간이면 전부'로 정함. codex exec는 stdin을 닫아야 함(</dev/null), 안 그러면 입력을 기다리다 멈춘다.

## iOS 제출 절차 (2026-11-06, Xcode 계정 없이)
- Xcode가 로그아웃이면 cloud signing이 'No Accounts'로 실패. API 키는 앱 관리 권한이라 cloud signing도 불가. 대신 API로 맥의 iPhone Distribution 인증서(CFCB75UTZP)를 쓰는 App Store 프로파일을 만들어 수동 서명 내보내기: Fokko AppStore / Fokko FocusMonitor AppStore / Fokko BreakActivity AppStore.
- 순서: xcodebuild archive → exportArchive(signingStyle manual) → IPA 권한 확인(family-controls) → altool 업로드(API_PRIVATE_KEYS_DIR=~/.config/fokko) → tool/asc_release.py → asc_screenshots.py·asc_preview.py → 처리 완료 대기 → 빌드 연결 → asc_submit.py.

- 2026-11-15 Play 비공개 테스트(개인 계정, D-U-N-S 포기). 접근성 서비스(앱 잠금) 선언에 '명시적 공개' 영상 필요 → 에뮬레이터로 lock_page 고지→설정 켜기 녹화, Drive 링크 공개. 스토어 그래픽은 AI 생성 애셋으로 라벨(캐릭터가 Higgsfield/codex 생성). Play 스크린샷은 2:1 이하라 iPhone 샷을 1080×2160에 맞춰 넣음(docs/mobile/store-assets/play).
