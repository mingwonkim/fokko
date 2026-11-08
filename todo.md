# FocusOne todo

## 2026-07-14
- [x] macOS 다운로드 차단(Gatekeeper) 해결 — CI에 ad-hoc 서명 추가 + README에 xattr 안내 + 로컬 빌드해 /Applications/FocusOne.app 설치
- [x] 숲/밤/바다 3개 장면 모드 (테마 색 전환, 확장 패널 상단 아이콘으로 선택, 저장됨)
- [x] 장면별 앰비언트 사운드 (숲소리/뻐꾸기+바람/파도, 합성 WAV 40초 루프, 집중 중에만 재생)
- [x] 디자인을 바탕화면 시안(.dc.html 3종)과 동일하게 재구현 — 미니 320×128 / 확장 400×560, 장면 다이얼·뱃지·불릿·푸터 통계 전부 시안 값 사용
- [x] UI 편의성 개선 — 다이얼↔컨트롤 세로 간격 확대, 인박스/차단 뷰에서 큰 다이얼을 소형 타이머 줄로 접어 내용 공간 ~3배 확보, 탭 터치 영역 확대
- [x] 사운드 on/off + 볼륨 조절 — 확장 패널 헤더 스피커 아이콘 → 팝업(토글+슬라이더), 설정 저장됨
- [x] 커밋 + 푸시 완료 (0cd61d9, main)

## 2026-10-08 — 앱 UI/UX v2 (design-pipeline, design-v2 브랜치)
- [x] Mobbin 후보 제시 → 사용자 A안(Tiimo) + 링 안 장면 아이콘 선택
- [x] PRD·레퍼런스·astra 설계서 (docs/v2/)
- [x] 구현: 토큰·굵은 링+장면 일러스트·미니·확장·소형 타이머·작업 카드(원형 체크)·인박스·퀵 캡처·모션 — analyze 0, test 3/3 통과
- [x] 미리보기 PNG 3장면×미니/확장 생성 (tool/preview)
- [x] 사용자 확정 → main 머지·푸시
- [ ] 실제 macOS 앱 실행 확인 (창 드래그·팝업 메뉴·우클릭 삭제)

## 2026-10-08 — 포트폴리오 미디어
- [x] 스크린샷 2장(미니·확장, 투명 PNG 3x) + 데모 영상 1920×1080 13.7초 → ~/Desktop/focusone-portfolio/
- [x] 렌더러 tool/media/media_test.dart (타임랩스·사운드 재생 표시, 소리 없음)

## 2026-10-08 — 앱 아이콘
- [x] 코드 렌더 4안 + Higgsfield 시안 8장 비교 → 사용자 H3(바다·고래) 선택 (크레딧 6.5 사용, 잔액 30.18)
- [x] macOS/Windows/Linux(.deb)/트레이 아이콘 생성 + tool/apply_icons.sh + CI 적용, 로컬 macOS 릴리즈 빌드에서 AppIcon 확인

## 2026-10-11 — 모바일(iOS+Android) v1 (브랜치 mobile-v1, 계획 ~/.claude/plans/zazzy-crunching-hammock.md)
- [x] P0 레퍼런스: Arctic Habit 실측(iPhone 미러링, 10분 세션 완료까지) + Mobbin + PRD + astra 설계서 → docs/mobile/
- [ ] P1 플랫폼 추가·셸 분리 + 차단 기술 시험(iOS 15분 shield, Android 접근성) + Family Controls 배포 권한 신청
  - [x] ios/android 추가 + 폰 셸(탭 4개) — iOS 시뮬(iPhone 17 Pro)·Android 에뮬(focusone-design) 실행 확인
  - [x] 아이폰 실기기 등록·서명·설치 (팀 QZ366AK4NB), FocusLock+FocusMonitor 확장 탑재
  - [x] 차단 기술 시험: 아이폰 실기기에서 잠금 동작 확인 (사용자, 2026-10-11) — 앱 종료 후 자동 해제는 P6에서 재확인
  - [x] Family Controls 배포 권한 신청 제출 (2026-10-11, Apple 회신 대기)
- [x] P2 저장 안전성 + 세션 복구·보상 1회 확정 — 시각 기준 타이머, 진행 세션 저장, .bak 복구, 테스트 6개
- [x] P3 데이터 모델(태그·친구·배치·재화) + 통계 — Progress 묶음 저장(schema 3), FocusStats(자정 분할·잔디·골든타임), 테스트 9개
- [x] P4 집중 홈 1장 → 사용자 검토 → 할 일·기록·인박스·알림 (astra 리뷰 1 12건 반영, 잔디 → 장면색 집중 달력) — 소리 선택 시트는 P7
- [x] P5 풍경(6×6 꾸미기)·보관함·도감·상점 + 친구 12종·장식 9종(codex 이미지 생성) + 집중 소리 시트(빗소리·백색·갈색 합성)
- [ ] P6 Deep Focus 본구현
  - [x] 정식 잠금 화면(안내·동의·권한·앱 선택·설정), 세션 연동(재생=잠금, 일시정지·종료=해제)
  - [x] Android 접근성 잠금 — 에뮬레이터에서 차단·만료 후 미차단 확인
  - [x] 아이폰 실기기: 정식 화면 잠금·앱 종료 후에도 유지 확인(10/11), 자동 해제는 사용자 확인 완료
  - [ ] Android 실기기 확인, Play 접근성 선언·시연 영상(출시 전)
- [x] 실사용 피드백 1 (2026-10-11): 폰 일시정지 제거, 화면 꺼져도 소리(just_audio·백그라운드 오디오), Mixkit 원음 11개로 교체 + 장면별 상황 소리 (docs/mobile/sounds.md)
  - [ ] 아이폰에서 화면 끔·반복 이음새 확인
  - [x] 그만두기 막기: 시작 10초 안에만 취소, 이후엔 물방울로 비상 탈출(남은 1분당 2개, 보상 없음)
  - [x] 도서관·기차·모닥불 Freesound CC0로 교체, 백색·갈색 음량 −20 LUFS로 맞춤
- [x] 랭킹 (2026-10-11): Supabase focusone(서울) 익명 계정+닉네임, 점수 = 모은 물방울 − 비상 탈출, 하루 +720 상한·경과 분 검증, 이번 주/누적, 나가기. 시뮬 참여·나가기 확인
- [x] 풍경 탭 → '꾸미기' (탭 안 버튼은 '배치 바꾸기')
- [x] 소리 시트 장면별 정리: 빗소리→숲, 바람→밤, 백색·갈색만 '집중 소음' 공통. 폰 밤 아이콘 별(+) → 달
- [ ] 아이폰에 최신 빌드 설치 (랭킹·꾸미기 탭 포함) → 실기기 랭킹 참여 확인
- [x] 앱 이름 FocusOne → Tocko → **Fokko** (2026-10-12, 보이는 이름·Android ID com.looinlabs.fokko·사이트 /fokko·ASC 이름. iOS 번들 ID 유지)
- [x] Android applicationId·패키지 → com.looinlabs.tocko (debug APK 빌드 확인)
- [x] 지원 https://looinlabs.com/tocko/ · 개인정보 https://looinlabs.com/tocko/privacy 배포 (랭킹 수집 항목 포함)
- [x] App Store Connect 앱 등록 (사용자) — app id 6821653231
- [x] ASC API 키 (~/.config/fokko/asc.env, 저장소 밖) + tool/asc*.py: 문구·카테고리·연령등급·무료·175개국·저작권·버전 1.0.0 반영
- [x] 심사 연락처·메모 (appStoreReviewDetail, API)
- [x] 앱 개인정보 게시 · Apple Silicon Mac 사용 가능 끔 (웹)
- [x] 스토어 스크린샷 6.9" 5장 업로드 (tool/media/seed_test.dart 예시 데이터 → Pro Max 시뮬)
- [x] iPad 대응 (배율 짧은 변/640 최대 1.6, 가로 두 칸) + iPad 13" 스크린샷 5장 — 심사가 iPad 스크린샷 요구
- [x] 빌드 3 업로드(Xcode Organizer — CLI 서명은 'No Accounts'로 실패) → 버전 연결 → 심사 제출 (2026-10-12 WAITING_FOR_REVIEW, 자동 출시)
- [x] 휴식 남은 시간: iOS Live Activity(Dynamic Island·잠금 화면, BreakActivity 확장) + Android 카운트다운 알림 — 시뮬 확인
- [x] 1.0 거부(10/14, 2.5.1 자동 검사: Family Controls 권한 없이 제출) — App ID에 FAMILY_CONTROLS_DISTRIBUTION 승인돼 있음. 빌드 4(휴식 Live Activity 포함)를 Organizer Custom→Export로 IPA 만들어 family-controls 포함 확인 후 altool 업로드
- [x] 빌드 4 버전 연결 → 재제출 (10/15 00:56, WAITING_FOR_REVIEW). API PATCH submitted=true는 "not ready"로 실패 → ASC 웹 "심사 업데이트"→"앱 심사에 다시 제출"로 해결
- [x] 1.0 2차 거부(10/15, 2.5.4 백그라운드 오디오 재생 안 들림) → astra 검토 반영, 빌드 5 업로드
  - [x] 소리: 끊김(전화·알림 등) 뒤 자동 재개, 로딩 직렬화·실패 재시도, 음량 0이면 정지 (실사용 화면 꺼짐 끊김 원인)
  - [x] 랭킹: 닉네임 자유 입력 → 단어 조합 자동 생성(UGC 회피), 나가기 = 익명 계정 삭제, 개인정보 처리방침 링크
  - [x] Live Activity: 앱 첫 동기화에서 남은 표시 정리
  - [x] 심사 메모 갱신(ASC·store.md)
  - [x] supabase db push (사용자 실행 10/16) — 익명 가입→leave_ranking→user_not_found 확인
  - [x] 실기기 증빙 영상: iPhone 미러링 창을 ScreenCaptureKit(창+앱 소리)로 녹화 — 백색소음 시작→홈 화면 소리 계속(-27dB) 확인, 심사 첨부·답장에 첨부
  - [x] 빌드 5 버전 연결, 아이폰 설치
  - [x] 해결 센터 답장(영상 첨부) → 재제출 (10/16 00:22, WAITING_FOR_REVIEW)
- [x] 스토어 홍보 스크린샷 6장(iPhone 6.9"·iPad 13", 문구+실제 화면) + 앱 프리뷰 23초(886×1920, 장면 소리) — tool/store, docs/mobile/store-assets (10/17, 사용자 검토 대기)
- [x] 1.0.0 승인·출시 확인 (10/18 READY_FOR_SALE)
- [x] Windows용 ASC API 키(fokko-windows, 앱 관리) → ~/.config/fokko/ · 업로드 스크립트가 편집 가능한 버전을 고르게(asc.ko_loc) · pubspec 1.0.1+6
- [x] 1.0.1 ASC 버전 생성 + 스크린샷 iPhone 6·iPad 6 + 앱 프리뷰 업로드 (10/18, 처리 완료 COMPLETE)
- [x] 1.0.1 빌드 6 업로드·처리 VALID·버전 연결 (10/18, family-controls 확인)
- [x] 1.0.1 새 기능 문구 + 심사 제출 (10/18, tool/asc_submit.py, WAITING_FOR_REVIEW)
- [x] 1.0.1 1차 거절(10/20, 2.3.4: 앱 프리뷰에 기기 테두리) → 프리뷰를 앱 화면 전체+상태바 문구로 재생성·업로드 → 10/25 재제출
- [x] 1.0.1 심사 결과 확인 — 승인·스토어 출시 (10/27, iTunes lookup 1.0.1, ASC 제출 COMPLETE)
- [ ] Android 휴식 알림 실기기 확인
- [ ] P7 모션 GIF·최종 미리보기 → 사용자 확정 → main 머지
- [ ] Android 출시: Play **조직 계정**(develop@looinlabs.com)으로 (2026-10-13 결정, 개인 계정 14일 테스트 대신)
  - [x] 서명 AAB 빌드 (업로드 키 CN=FocusOne, android/key.properties → ~/.config/focusone)
  - [x] 주소: 비상주 사무실 안 함 — 하루전(개인 계정, 인앱 구매)에 이미 공개돼 있음
  - [x] D-U-N-S 신청 제출 (2026-10-13, Apple duns-lookup 무료, 사업자 주소) → 발급 1~2주 대기, 안내 메일 develop@looinlabs.com
  - [x] D-U-N-S 재신청 제출 — 2026-11-06 D&B Apple 지원 양식, 사건 #34993712, 영문 사업자등록증 첨부, 상호 looin labs. 안내: 해외 7~14영업일. 회신 develop@looinlabs.com(Safari Gmail u/1). 다음: 번호 받으면 Play 조직 계정 가입
  - [ ] 11/08 확인: develop@ 받은편지함·스팸함에 D&B 메일 없음(접수 확인 메일도 없음). 예상 회신 11/17~11/26
  - 이전 거절 기록: 10/16 D&B 답: 'D-U-N-S Number could not be created / Required documents not provided'. 회사 존재 확인 불가, 홈택스 영문 사업자등록증 사본 요구(추적 11045680, 사건 11104000, 요청 키 BYFVC73Y96). 메일 회신 불가 주소라 제출 경로 확인 필요
  - 주의: 조직 계정은 법적 주소·개발자 전화·이메일이 Play에 공개됨(숨김 불가, D&B 기록과 일치 필요). Fokko는 번호 결과 전까지 개인 계정에 앱 만들기 금지(패키지 이름 선점 방지)
  - [ ] Play 조직 계정 가입($25 사용자 결제) → 서비스 계정 API 키 ~/.config/fokko/
  - [ ] Play 스토어 자료(문구·스크린샷 1080×1920·그래픽 1024×500·아이콘 512)·접근성 선언·시연 영상
  - [ ] 첫 AAB 업로드 → 심사 제출
- [x] iOS 출시: Family Controls 배포 권한 승인 대기(10/11 신청) → 아카이브 → TestFlight → 심사 — 1.0.0 출시(10/18)

## 2026-11-04 — 소리 튐 + 게임화
- [x] 소리 갑자기 커짐: 원인 = 음원 안 큰 소리 구간(중앙값 +11~16dB) + 반복 경계 음량 단차(+6dB) + 리미터 지연 5ms 무음(4개). 2초 원형 레벨러·지연 보정으로 전체 재처리 → 최대−중앙 ≤8dB, 경계 ≤3dB
- [x] 게임화 1차안 (Fable 계획, 문턱 절반: 씨앗→새싹 30분 … 마스터 500h): 칭호 10단계·테두리 아바타(높은 단계 회전·빛·별)·기록 탭 프로필 카드·승급 축하(보상 시트)·명예의 전당(이번 주/이번 달/누적, 시상대, 지난 1~3위 보존)·공유 카드(share_plus). 로컬 Postgres로 SQL 검증, 테스트 36개 통과
  - [ ] 사용자 디자인 검토 (미리보기: flutter test tool/preview/game_capture_test.dart --dart-define=OUT=<dir>)
  - [x] `supabase db push` (11/04 Claude, CLI 연결돼 있음) — 출시된 1.0.x가 쓰는 옛 submit_score·ranking은 남기게 고친 뒤 반영. 실서버에서 옛·새 ranking·past_winners 응답 확인
  - [ ] 실기기: 공유 시트 PNG(카톡·사진 저장), 승급 시트 확인
  - [x] 개인정보 처리방침에 아바타(친구 id) 추가 — 11/06 문서 수정
- [x] 2차 (11/05): 꾸미기 보관함·도감·상점 탭바 위 고정 / 칭호 배지(메달+링 색)·10단계 사다리·다음 목표 카드(남은 시간·%·다음 테두리) / 승급 시트에 배지·다음 목표
- [x] 1:1 대결 (11/05, 이번 주 월~일 집중 분 = daily_points.gained, 친구 여럿, 전적): 서버 20261105000000_friend_duels.sql(초대 코드·친구·duels·끊기, 로컬 pg 검증), 기록 탭 대결 카드 + 대결 화면(줄다리기 막대·코드 입력·길게 눌러 끊기), 카톡 초대(kakao_flutter_sdk_share, 키 없으면 공유 시트로 코드+스토어 링크), 초대 링크로 열리면 대결 화면 자동 수락. 테스트 39개 통과
  - [x] `supabase db push` 20261105000000_friend_duels.sql — 11/06 사용자 실행 완료
  - [x] 카카오 개발자 앱 생성(사용자) → 네이티브 앱 키 받으면: invite.dart kakaoNativeKey, Info.plist CFBundleURLTypes kakao<키>, AndroidManifest intent-filter kakao<키>://kakaolink — 11/06 완료
  - [x] 개인정보 처리방침에 친구 대결(초대 코드·친구 관계) 추가 — 11/06 문서 수정

## ▶ 재부팅 후 이어서 (2026-11-05 기준, 브랜치 mobile-v1, 전부 푸시됨 abe590a)
1. [x] 사용자: `supabase db push` (또는 Claude에게 "db push 해도 돼") — 대결 마이그레이션 20261105000000_friend_duels.sql. 전엔 대결 카드 "불러오지 못했어요" — 11/06 사용자 실행 완료. 실서버 RPC 4개 존재·비로그인 차단(401) 확인, 로그인 상태 동작은 실기기에서 확인
2. [x] 사용자: developers.kakao.com 앱 생성 → 플랫폼 iOS(번들 com.looinlabs.focusone, 앱스토어 ID 6821653231)·Android(패키지 com.looinlabs.fokko + 키 해시)·Web(https://looinlabs.com) → 네이티브 앱 키 Claude에게 — 11/06 computer use로 완료: 앱 ID 1639218, 업로드·디버그 키 해시 등록. Play 출시 때 Play 앱 서명 키 해시 추가 필요
3. [x] Claude: 키 받으면 invite.dart kakaoNativeKey + Info.plist CFBundleURLTypes kakao<키> + AndroidManifest intent-filter(scheme kakao<키>, host kakaolink) → 빌드·아이폰 설치(폰 잠금 해제 필요) — 11/06 코드 반영(analyze 0, 테스트 39개), 아이폰 설치 완료(flutter install 실패 → xcrun devicectl device install app 성공)
4. [ ] 사용자: 디자인 검토 2차 — 미리보기 다시 만들기: `flutter test tool/preview/game_capture_test.dart --dart-define=OUT=<dir>` (scratchpad 이미지는 재부팅 시 사라짐) — 11/06 재생성 17장, 사용자 검토 대기
5. [ ] 실기기 확인: 공유 시트·승급 시트·소리·대결 카드
6. [x] 출시 전: 개인정보 처리방침에 아바타·초대 코드·친구 관계 추가 — 11/06 looinlabs 커밋, 배포는 사용자
- 참고: 로컬 Postgres 테스트 DB는 scratchpad에 있어 재부팅 후 사라짐 — 필요 시 다시 만듦

## 2026-11-06 — v3 성장하는 재미 (design-pipeline, 브랜치 growth-v3, worktree ../focus-one-v3)
- 결정: 첫 화면 집중 시작 유지 + 성장 지도 별도 탭 / 원 유지 + 화면 전체 차오름(바다 파도·숲 풀과 나무·밤 달빛과 별·일상 커피) / 듀오링고 구조 최대한(하트 제외, 고유 자산 복제 금지) / 일일·주간 목표 직접 설정 / 이미지 codex
- [x] PRD docs/v3/PRD.md
- [x] astra 설계서 docs/v3/app-design-spec.md — 5단계 구현 순서, 리그는 3등급 지연 정산
- [x] Mobbin 레퍼런스 docs/v3/refs/app-growth.md — 7개 영역, 듀오링고 구조 + TIDE·Oura 전체 화면
- [x] 1단계 1차안 구현: 집중 화면 차오름 4장면(lib/mobile/focus/scene_fill.dart) + 입체 버튼·카드(widgets/chunky.dart) + 스탯 바 — analyze 0, 테스트 45개. 미리보기: flutter test tool/preview/fill_capture_test.dart --dart-define=OUT=<dir>
- [x] 피드백 1 반영: 숲 물들며 자라는 숲 / 밤 우주처럼 어두워짐 / 일상 커피 차오름
- [x] 피드백 2 반영: 링도 0에서 차오름(배경과 방향 통일) / 밤 해질녘→우주 / 일상 아이스 아메리카노
- [x] 피드백 3 반영: 커피 빨대 제거, 바다와 같은 2겹 출렁임
- [x] 피드백 4 반영: 링 안쪽 불투명 바탕. 친구 점점 선명해짐은 사용자 요구로 유지
- [ ] 사용자 검토 대기 (1차안 수정본 4). 실기기 설치·전력 측정 미실시
- [x] 2단계: 일일·주간 목표(lib/models/growth.dart, 올리면 즉시·낮추면 다음 기간), XP=완료 분, 연속일+얼음(최대 2, 물방울 30, 자동 사용), 이행(구버전 파일 보존, 이전 중단 기록 인정), 목표·연속일 화면, 보상 시트 줄 — analyze 0, 테스트 70개. 미리보기: flutter test tool/preview/growth_capture_test.dart --dart-define=OUT=<dir>
- [x] 피드백 5·6: 젤리·글꼴은 사용자가 거절 → 처음 디자인으로 복귀(카드·알약·탭바·링·시스템 글꼴). 불꽃·물방울·얼음은 장면 색. 기능은 유지
- [x] 처음 디자인 복귀 확정. 사용자: 폰 설치는 제일 마지막에 (단계 중간에 묻지 말 것)
- [x] 3단계 끝나면 아이폰 설치 (사용자 요청 11/06) — devicectl 설치 성공
- [x] 3단계: 성장 탭(지도 25XP마다 칸·칭호 큰 칸, 퀘스트 3개·상자, 업적 4개), 친구 성장 3단계(120·600분, 도감→친구 화면), 보상 시트 줄 — analyze 0, 테스트 86개
- 사용자 11/06 취침 전 지시: 4단계·5단계·개인정보 처리방침 갱신. 실서버 db push·스토어 제출은 하지 않고 준비만
- [x] 4단계 코드: 리그 SQL(로컬 pg 50개 검증, tool/test_league_sql.sh), 세션 예약·제출 재시도(league_sync), 리그 화면 — 테스트 102개
- [x] 실서버 반영 `supabase db push` (20261107000000_league.sql) — 11/06 사용자 지시로 Claude 실행. worktree는 연결 정보(supabase/.temp, git 제외)를 main에서 복사해야 함. 비로그인 호출로 함수 5개 존재·차단(401) 확인. 로그인 상태 동작은 실기기에서 확인 필요
- [x] 처리방침 사이트 배포 — 11/06 사용자 지시로 Claude 실행 (버전 2b7d770e)
- [ ] 출시 때: ASC 앱 개인정보 항목 재점검(리그·친구 데이터)
- [x] 5단계 일부: 접근성 자동 검사, 낭독기 누르기 동작 수정, 그리기 비용(최대 1.7ms/프레임, 대리 지표), macOS·Android arm64·iOS 빌드, 시뮬레이터 흐름 확인
- [x] 접근성: 버튼 이름 중복·원형 버튼 역할·목표 입력 터치 크기 수정 — 테스트 121개
- [ ] 남음(사용자·실기기 필요): 실기기 배터리 측정, Android 실기기 확인
- [ ] 스토어 프리뷰 문구 점검 (tool/store/store_test.dart '선명해져요'는 유지됨, 링 차오름은 재촬영 필요)
- 사용자 확정 전 main 머지 금지

## 다음 세션
- [x] GitHub Actions 빌드 통과 확인 — 실패는 10/07 미사용 import 1회(다음 커밋에서 해결), 이후 main 4회 연속 성공
- [x] GitHub Actions에서 아이콘 단계(Windows bash·.deb Icon) 통과 확인 — 66f0fb8 성공
- [ ] (보류) 주간 랭킹 상위 5명 커피 쿠폰 — 사용자 50명 이상일 때. 필요: Apple/Google 로그인 자격, 동점 = 먼저 도달, 상위 기록 수동 확인, 당첨자 연락처 동의, 앱 내 공식 규칙
- [ ] (나중에) 내부 ID를 Tocko로 — 사용자 결정 2026-10-12: 지금은 보이는 이름만 Tocko, iOS 번들 ID는 출시 위해 유지
  - iOS 번들 ID com.looinlabs.focusone(+ .FocusMonitor), App Group group.com.looinlabs.focusone → tocko: Family Controls 배포 승인을 새 ID로 다시 받아야 함(수일~수주). 승인 후 업데이트로
  - 채널 이름 focusone/lock, ManagedSettingsStore 'focusone', Dart 패키지 focus_one, CI 산출물 이름 focus-one, 저장소 이름
  - 주의: 데이터 파일 focus_one_data.json·데스크탑 앱 데이터 경로는 패키지명에 묶임 → 바꾸면 기존 기록 이전 코드 필요
- [ ] (나중에) macOS 버전 출시 — 폰 출시 후. macos/ 커밋·앱 이름 Tocko(지금은 focus_one으로 보임)·Developer ID 서명+공증 또는 Mac App Store
- [ ] (보류) Apple Developer 공증 — 경고 없는 배포가 필요해지면

## v3 사용자 피드백 (11/06 폰 확인 후)
- [x] 지도: 칸 약 1,200개 → 63개, 칸마다 레벨 숫자, 머리에 Lv·다음 레벨 막대, 홈 스탯·완료 시트에 레벨. 칭호 글자 18pt 강조
- [x] 퀘스트 추가: 오늘 75분(물방울 20), 이번 주 225분(40)·450분(80). 내 목표와 같으면 겹치지 않음
- [x] 업적 90·180·365일 연속
- [x] 친구: 기본 4종은 캐릭터당 1명 고정(세션으로 안 늘어남), 꾸미기 친구칸은 기본 4종 + 그 장면 친구
- [x] 친구 36종 확장: codex로 20종 추가(장면당 9종), 해금 장면별 0~1500분 또는 전체 100시간
- [x] 도감 조건: 사용자 요청으로 상향 후 100시간 전부 해금 기준으로 재조정. 이미 만난 친구는 유지
- [x] 차오름: 0초에 바닥에서 시작, 끝 시각에 정확히 가득. 숲 마지막 줄도 끝에 다 자람. 얼음 입체 큐브
- [x] 잠금 유지 확인: 아이폰 덮어쓰기 설치 후 선택 앱 유지 확인, 켜짐 값을 바꾸는 코드는 사용자 조작뿐. 폰 값은 현재 꺼짐
- [x] 차오름 품질: 바다(수심·빛줄기·물고기·기포), 숲(언덕·음영·뾰족 나무·꽃가루·낙엽, 맨 위 줄 줄기 수정), 밤(성운·반짝이는 별·별똥별·고리 행성)
- [x] 지도 칭호 꾸미기 1차안: 칭호별 색 구간·테두리·장식(잎·초승달·별·물결·기포·왕관빛), 상단 카드 테두리. 미리보기 tool/preview/title_map_capture_test.dart. 폰 미설치, 사용자 검토 대기
- [x] 지도 진행도 강화 1차안: 칭호 구간 배경 그라데이션, 지나온 칸 체크·굵은 실선, 안 간 칸 옅은 색·점선, 지금 칸 확대·퍼지는 링·말풍선, 지금 위치로 버튼. 폰 미설치, 사용자 검토 대기
- [x] 꾸미기 친구칸: 친구 36종 전부 표시(못 만난 친구는 그림자), 다른 장면에 놓인 기본 친구는 옮겨 올 수 있음
- [x] 꾸미기 풍경 하나로 통합(장면 구분 제거, 그라데이션 바닥, 예전 배치 모두 이전)
- [x] 꾸미기 형식: 사용자가 A 그라데이션 선택, 동물원 안 함
- [x] 꾸미기 그라데이션: 장면별 두 색(숲 크림→민트, 밤 남색→보라, 바다 하늘→라벤더, 일상 살구→코랄 핑크)
- [ ] 실제 스토어 업데이트·Android 업데이트 후 잠금 유지 확인 (실기기 필요)
- [x] 이번 수정본 폰 설치 (11/06)

## v3 리뷰·에뮬레이터 결과 (11/06, Android 16 에뮬레이터)
- 통과: 전 탭 렌더, 꾸미기 배치, 세션 완료·보상, 세션 중 앱 차단, 덮어쓰기 업데이트 후 권한·세션·차단 유지, 종료 시각 후 해제
- [x] 수정: 꾸미기 완료 버튼이 친구 36종 목록 아래로 밀림
- [x] 수정: 접근성 권한이 꺼져도 '앱 잠금 켜짐' 표시, 안내 없음 (강제 종료하면 Android가 권한을 끔: 실측)
- [x] 수정: 세션 중 권한을 켜면 그 세션엔 잠금이 안 걸림
- [x] 수정: 리그 점수 유실(begin이 끝난 미제출 세션 취소, begin이 outbox보다 먼저), 후속 마이그레이션 필요
- [x] 수정: 월요일 유예 구간 배정이 지난주 승급·강등을 지움, 후속 마이그레이션 필요
- [x] 수정: 재실행 begin이 오프라인 세션에 새 예약 생성 후 outbox 막힘
- [x] 수정: 업데이트 직후 첫 완료가 이전 분까지 합산해 퀘스트 일괄 지급 / 목표 올리면 고정 퀘스트 중복 지급
- [x] 수정: 구 기준 해금·미보유 친구 재잠금, 목표 '내일부터 적용' 문구 안 사라짐, 리그 동점 구분선
- [x] 수정: iOS 재실행 후 15분 미만이면 그만둬도 잠금 해제 안 함 (main에도 있는 기존 버그)
- [x] 실서버 반영: 20261108000000_league_fixes.sql — 11/06 사용자 지시로 Claude 실행
- [x] 실서버 시험 (에뮬레이터): 익명 가입, 리그 참여, 10분 세션 서버 시계 인정·조 배정·순위 표시, 탈퇴. 테스트 계정 삭제. 일반 앱 종료 후 차단 유지 확인
- [x] CI Linux: ubuntu-24.04 고정으로 복구 (a64065a)
- [ ] 미확인: 오프라인 종료 후 점수 재전송은 실서버 왕복 미시험(로컬 SQL·위젯 테스트만), 삼성 등 실기기

## v3 출시 자료 (11/06, 업로드 전)
- [x] 스토어 문구·Play 답안: docs/v3/store.md (글자 수 검사 통과)
- [x] 스크린샷: iPhone·iPad·Android 8장, Play 그래픽, 아이콘 512, iOS 프리뷰: docs/v3/store-assets/
- [x] 접근성 시연 영상: android/accessibility_demo.mp4 (에뮬레이터 촬영)
- [ ] 사용자: store.md의 [확인] 항목, 시연 영상 링크 등록, 동의·선언 제출
- [x] iOS 1.1.0 (7) 심사 제출 — 11/06 18:27 WAITING_FOR_REVIEW, 승인 후 자동 출시, 제출 코드 d21da3b(growth-v3)
- [ ] iOS 1.1.0 심사 결과 확인
- [x] growth-v3를 main에 병합 (3441fa7), 워크트리 focus-one-v3와 브랜치 삭제 — 이후 main에서 작업
- [ ] 사용자: ASC 앱 개인정보 항목 확인 (API로 볼 수 없음)


## 경쟁·연속 배너·스크린샷 (11/08)
- [x] 기록 탭 → '경쟁' (트로피 아이콘). 탭 안에 1:1 대결 카드가 있어 '대결'은 겹쳐서 '경쟁' 선택
- [x] 듀오링고 조사: 오늘 첫 완료에 Duo가 불꽃으로 변하는 연속 화면, 마일스톤(7·30·100…)은 더 크게, 주간 리그·친구 퀘스트
- [x] 연속 집중 배너: 오늘 첫 완료로 연속 2일 이상이 되면 보상 시트 맨 위 주황 배너 — 친구가 세 번 뛰고 불꽃·일수·최근 7일 체크. AppState.lastStreakExtended, 테스트 2개
- [x] 스크린샷 8장 다시 찍음(iPhone·iPad·Android): 숲·바다·밤·일상 각 2장, 03 연속 배너 컷, 08 경쟁. 할 일 컷은 뺌
- [ ] 사용자: 새 스크린샷 스토어 업로드 (iOS 1.1.0 심사 중이라 다음 버전 또는 승인 후), 폰 설치 확인
- [ ] 프리뷰 영상은 다시 안 찍음 (스크립트의 탭 이름만 '경쟁'으로 수정)
- [x] 이름 변경: GitHub mingwonkim/focus-one → fokko(옛 주소 자동 연결), 로컬 ~/CodingProjects/fokko, Orca 새로 등록·표시 이름 fokko. 번들 ID·패키지명·CI 산출물 이름은 그대로
- [ ] 사용자: Orca에 남은 옛 'focus-one' 항목 지우기 (CLI에 삭제 명령 없음)

## 이어폰·잠금 화면 시간·재실행 잠금 (11/08)
- [x] 이어폰 끊기면 백색소음 영영 안 남 → 끊기면 무음으로 계속 재생(앱 안 잠듦), 출력 장치 다시 붙으면 소리 복구. 소리 껐다 켜면 스피커로 정상 재생 (사용자 선택: 멈췄다가 재연결 시 재생)
- [x] 잠금 화면 남은 시간: 집중(진행·일시정지)도 Live Activity — 64pt 큰 카운트다운, Dynamic Island. Android는 줄어드는 시계 알림(잠금 화면 공개)
- [x] 앱 재실행 시 잠금 풀림: 재실행마다 start→stopMonitoring이 확장 intervalDidEnd를 불러 방금 건 잠금 해제. 같은 세션이면 예약 유지 + 예약 이름에 종료 시각 넣어 activeActivity로 비교
- [x] 아이폰 설치 (듀오링고 참고 연속 배너 포함 빌드)
- [x] 잠금 화면 카드 2차: 앱처럼 장면 색 링 + 링 안에 세션 친구(빌드 단계 Copy Companions가 webp→192px png로 확장에 복사), 반투명 장면 바탕, 시간은 오른쪽 크게. 색은 친구의 장면에서. 시뮬레이터로 진행·일시정지·밤/숲 렌더 확인
- [x] 이어폰: 끊기면 무음 대기, 다시 잡히면(또는 앱 복귀 시 확인) 복구. 사용자가 소리 다시 켜면 연결된 출력으로 — 블루투스 없을 때만 스피커
- [x] 독립 검토 반영: 재실행 빠른 경로에 예약 존재 확인, 제목 80자 제한(4KB), just_audio pause 기다림, 장치 조회 예외 처리
- [x] 아이폰 재설치
- [ ] 실기기 확인: 이어폰 끊고 다시 연결, 잠금 화면 카드(초 단위 흐르는지 — 시뮬레이터는 '17:--'로 가림), 집중 중 앱 껐다 켜도 잠금 유지
- [ ] 알려진 한계: 소리 꺼진 채 앱이 잠든 사이 세션이 끝나면 카드가 0:00으로 남음(앱 열면 정리)
- [x] 켤 때마다 '앱 잠금이 꺼져 있어요' → 자물쇠 화면 들어가야 켜짐: 앱 시작 직후 스크린타임 권한이 잠깐 notDetermined로 읽힘(추정). status가 실제 값을 최대 2초 기다림, 시작 시 확인은 앱 실행을 막지 않게
- [x] 잠금 화면 카드: 할 일 없을 때 넣었던 '다른 앱 말고 이것만' 문구 제거(줄 비움). 카드 위치는 iOS가 정해 중앙 이동 불가
- [x] 아이폰 재설치 (11/08 세 번째)
- [ ] 실기기 확인: 앱 껐다 켠 뒤 바로 시작해도 '앱 잠금이 꺼져 있어요' 안 뜨는지
- [x] 잠금 화면 카드 3차: 링·머리글을 장면 강조색으로(바다 하늘색 묻힘 수정), 바탕 불투명도 0.8, 링 100·숫자 60pt. StandBy(충전 중 가로) 전체 화면이면 링 128·숫자 84pt, 할 일 줄 생략 — StandBy는 시뮬레이터 불가, 실기기 미확인
- [x] astra 조사(11/08): 세로 잠금 화면 중앙·전체 화면 표시 공개 API 없음. StandBy·카드 개선 채택, AlarmKit 종료 알람은 보류
- [x] 아이폰 재설치 (11/08 네 번째)
- [x] 실시간 현황 꺼짐 안내: 집중 시작 시 iOS 실시간 현황이 꺼져 있으면 '잠금 화면에 남은 시간 보기가 꺼져 있어요 [켜기]' → iOS 설정의 Fokko 열기 (사용자 선택: 시작 시 안내, 앱엔 설정 화면 없음). 아이폰 설치
- [x] StandBy 위 작은 원·다이내믹 아일랜드: 칸을 꽉 채운 굵은 링 + 캐릭터(크기는 iOS 고정이라 칸 안에서 최대). 시뮬레이터 다이내믹 아일랜드로 확인, 아이폰 설치
- [ ] 실기기 확인: StandBy 위 원 모양, 눌러서 전체 화면 배치
- [x] 작은 원에 펼치기 표시 겹침 — 오른쪽 아래 화살표(arrow.down.right)로 사용자 확정, 아이폰 설치
