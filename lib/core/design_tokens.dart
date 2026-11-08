// lib/core/design_tokens.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 디자인 토큰. 하드코딩 색상/매직넘버 금지 — 반드시 여기서 참조한다.
/// 디자인 언어: v2 — Tiimo 집중 화면 레퍼런스 + 링 안 장면 일러스트 (docs/v2/).
abstract class AppColors {
  // 장면(FocusScene)과 무관한 공통 시맨틱 컬러
  static const onPrimary = Color(0xFFFFFFFF);
  static const error = Color(0xFFFF3B30); // iOS 레드
  static const success = Color(0xFF34C759); // iOS 그린
  // 연속 집중 배너 불꽃 (장면과 무관하게 같은 주황)
  static const streakTop = Color(0xFFFFB020);
  static const streakBottom = Color(0xFFFF6A00);
  static const streakDim = Color(0x55FFFFFF); // 비어 있는 날 점
}

/// 화면 분위기 모드: 숲 / 밤 / 바다 / 일상. 각 모드는 스타일 + 앰비언트 사운드를 가진다.
enum FocusScene {
  forest,
  night,
  ocean,
  daily; // 카페·도서관·기차·모닥불 같은 일상 장소

  SceneStyle get style => switch (this) {
        forest => SceneStyle.forest,
        night => SceneStyle.night,
        ocean => SceneStyle.ocean,
        daily => SceneStyle.daily,
      };

  FocusScene get next =>
      FocusScene.values[(index + 1) % FocusScene.values.length];

  /// 앰비언트 사운드 애셋 경로 (forest.wav / night.wav / ocean.wav, 일상은 카페)
  String get soundAsset => this == daily ? 'sounds/cafe.m4a' : 'sounds/$name.wav';

  /// 폰 장면 기본 소리 id (assets/sounds/<id>.m4a, Mixkit 원음)
  String get phoneSound => this == daily ? 'cafe' : name;

  /// 폰 소리 시트의 장면별 상황 소리 id (백색·갈색소음만 모든 장면 공통)
  List<String> get situationSounds => switch (this) {
        forest => const ['birds', 'stream', 'rain'],
        night => const ['crickets', 'wind'],
        ocean => const ['harbor', 'rocky'],
        daily => const ['library', 'train', 'fire'],
      };
}

/// 장면별 스타일 값 — v2(Tiimo 레퍼런스) 팔레트. 근거: docs/v2/app-design-spec.md §3.
/// 작은 글자에 투명도 금지 — 전부 불투명 sRGB. 대비는 spec 표 참조(텍스트 ≥5:1).
class SceneStyle {
  const SceneStyle({
    required this.brightness,
    required this.cardBg,
    required this.cardBorder,
    required this.rowBg,
    required this.rowShadow,
    required this.textStrong,
    required this.textMuted,
    required this.textFaint,
    required this.accent,
    required this.ringProgress,
    required this.ringTrack,
    required this.dialColors,
    required this.dialStops,
    required this.pillBg,
    required this.pillFg,
    required this.checkBg,
    required this.checkFg,
    required this.divider,
    required this.fieldFill,
    required this.sceneLabel,
    required this.boardTop,
    required this.boardBottom,
    required this.footerLabel,
    required this.footerUnit,
    required this.fillShade,
    required this.fill,
    required this.fillDeep,
    required this.fillCrest,
    this.fillGlow,
  });

  final Brightness brightness;

  final Color cardBg; // 창 바탕
  final Color cardBorder; // 창 테두리 1px (창 외부 그림자 없음)
  final Color rowBg; // 리스트 카드·입력
  final Color? rowShadow; // 카드 그림자 (밤은 없음)

  final Color textStrong; // 제목·시간·작업
  final Color textMuted; // 라벨
  final Color textFaint; // 보조·완료

  final Color accent; // 작은 강조 글자·선택 테두리
  final Color ringProgress;
  final Color ringTrack;
  final List<Color> dialColors; // 링 안 풍경 하늘 그라데이션
  final List<double> dialStops;

  final Color pillBg; // 주 동작 알약 버튼
  final Color pillFg;
  final Color checkBg; // 완료 체크
  final Color checkFg;

  final Color divider;
  final Color fieldFill;

  final String sceneLabel; // 헤더 장면 칩 ("숲")
  final Color boardTop; // 꾸미기 풍경 그라데이션 위
  final Color boardBottom; // 아래
  final String footerLabel; // "오늘 심은 나무"
  final String footerUnit; // "그루"

  // 폰 v3 집중 중 화면 전체 차오름
  final Color fillShade; // 숲: 짙은 나무·땅
  final Color fill; // 뒤층·연한 나무·밤 시작색·커피 표면
  final Color fillDeep; // 앞층·진한 나무·우주 끝색·커피 바닥
  final Color fillCrest; // 물마루·얼음·별 등 밝은 점
  final Color? fillGlow; // 밤: 시작 하늘의 아래쪽 노을빛

  static const forest = SceneStyle(
    brightness: Brightness.light,
    cardBg: Color(0xFFEEF7F1),
    cardBorder: Color(0xFFDCEEE3),
    rowBg: Color(0xFFFFFFFF),
    rowShadow: Color(0x0F000000),
    textStrong: Color(0xFF162D22),
    textMuted: Color(0xFF405B4C),
    textFaint: Color(0xFF596C61),
    accent: Color(0xFF246B4B),
    ringProgress: Color(0xFF4F8D6D),
    ringTrack: Color(0xFFDCEEE3),
    dialColors: [
      Color(0xFFF0FFF4),
      Color(0xFFD2F7DC),
      Color(0xFF8FE2AB),
      Color(0xFF52C47C),
    ],
    dialStops: [0, 0.32, 0.66, 1],
    pillBg: Color(0xFF191B1A),
    pillFg: Color(0xFFFFFFFF),
    checkBg: Color(0xFF246B4B),
    checkFg: Color(0xFFFFFFFF),
    divider: Color(0xFFDCEEE3),
    fieldFill: Color(0xFFFFFFFF),
    sceneLabel: '숲',
    boardTop: Color(0xFFFFF3CC), // 크림
    boardBottom: Color(0xFFBDEBD3), // 민트
    footerLabel: '오늘 심은 나무',
    footerUnit: '그루',
    fillShade: Color(0xFF14715D),
    fill: Color(0xFF83DCC1),
    fillDeep: Color(0xFF22B894),
    fillCrest: Color(0xFFD9F5E7),
  );

  // 밤: spec은 라벤더(#C2B4ED)였으나 달·별 일러스트와 맞춰 달빛 골드 유지 — docs/v2/app-deviations.md
  static const night = SceneStyle(
    brightness: Brightness.dark,
    cardBg: Color(0xFF14131A),
    cardBorder: Color(0xFF2A2833),
    rowBg: Color(0xFF24222D),
    rowShadow: null,
    textStrong: Color(0xFFF6F3FC),
    textMuted: Color(0xFFCEC8DE),
    textFaint: Color(0xFFAAA6B8),
    accent: Color(0xFFE3C77F),
    ringProgress: Color(0xFFE3C77F),
    ringTrack: Color(0xFF3A3528),
    dialColors: [
      Color(0xFF232C4A),
      Color(0xFF171F38),
      Color(0xFF0D1222),
    ],
    dialStops: [0, 0.4, 1],
    pillBg: Color(0xFF34313F),
    pillFg: Color(0xFFFFFFFF),
    checkBg: Color(0xFFE3C77F),
    checkFg: Color(0xFF14131A),
    divider: Color(0xFF2A2833),
    fieldFill: Color(0xFF24222D),
    sceneLabel: '밤',
    boardTop: Color(0xFF2E2F6B), // 남색
    boardBottom: Color(0xFF7652A8), // 보라
    footerLabel: '오늘 모은 별',
    footerUnit: '개',
    fillShade: Color(0xFF9A7428),
    fill: Color(0xFF3F42A6),
    fillDeep: Color(0xFF04040A),
    fillCrest: Color(0xFFF4F1FF),
    fillGlow: Color(0xFF9A6FD6),
  );

  static const ocean = SceneStyle(
    brightness: Brightness.light,
    cardBg: Color(0xFFEFF7FC),
    cardBorder: Color(0xFFDDEDF7),
    rowBg: Color(0xFFFFFFFF),
    rowShadow: Color(0x0F000000),
    textStrong: Color(0xFF142F40),
    textMuted: Color(0xFF405E70),
    textFaint: Color(0xFF536D79),
    accent: Color(0xFF246587),
    ringProgress: Color(0xFF568CAD),
    ringTrack: Color(0xFFDDEDF7),
    dialColors: [
      Color(0xFFEEF9FF),
      Color(0xFFC9E9F8),
      Color(0xFF7CBFE7),
      Color(0xFF3585BD),
    ],
    dialStops: [0, 0.3, 0.64, 1],
    pillBg: Color(0xFF191B1A),
    pillFg: Color(0xFFFFFFFF),
    checkBg: Color(0xFF246587),
    checkFg: Color(0xFFFFFFFF),
    divider: Color(0xFFDDEDF7),
    fieldFill: Color(0xFFFFFFFF),
    sceneLabel: '바다',
    boardTop: Color(0xFFC8EEFF), // 하늘
    boardBottom: Color(0xFFDCD3F9), // 라벤더
    footerLabel: '오늘 만난 고래',
    footerUnit: '마리',
    fillShade: Color(0xFF227A9D),
    fill: Color(0xFF72CCE9),
    fillDeep: Color(0xFF36BDEB),
    fillCrest: Color(0xFFE4F7FD),
  );

  // 일상: 피치·코랄 파스텔 (베이지 금지). 대비: accent #A3452F / cardBg ≈ 5.9:1
  static const daily = SceneStyle(
    brightness: Brightness.light,
    cardBg: Color(0xFFFFF2EE),
    cardBorder: Color(0xFFFBDDD4),
    rowBg: Color(0xFFFFFFFF),
    rowShadow: Color(0x0F000000),
    textStrong: Color(0xFF3A1F18),
    textMuted: Color(0xFF6B4A41),
    textFaint: Color(0xFF7D5E55),
    accent: Color(0xFFA3452F),
    ringProgress: Color(0xFFE08A6E),
    ringTrack: Color(0xFFFBE0D8),
    dialColors: [
      Color(0xFFFFF6EC),
      Color(0xFFFFE1D3),
      Color(0xFFF7B9A2),
      Color(0xFFE59478),
    ],
    dialStops: [0, 0.35, 0.7, 1],
    pillBg: Color(0xFF2B1D1A),
    pillFg: Color(0xFFFFFFFF),
    checkBg: Color(0xFFA3452F),
    checkFg: Color(0xFFFFFFFF),
    divider: Color(0xFFFBE0D8),
    fieldFill: Color(0xFFFFFFFF),
    sceneLabel: '일상',
    boardTop: Color(0xFFFFEBC8), // 살구
    boardBottom: Color(0xFFFFC6C2), // 코랄 핑크
    footerLabel: '오늘 마신 커피',
    footerUnit: '잔',
    fillShade: Color(0xFFAC5948),
    fill: Color(0xFF8F5220),
    fillDeep: Color(0xFF7A4720), // 진한 알약 버튼이 묻히지 않는 밝기
    fillCrest: Color(0xFFF4FBFF),
  );
}

abstract class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // 폰 4/8 리듬 (데스크탑 기존 이름은 그대로 둠)
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
}

abstract class AppRadius {
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 16; // 리스트 카드·입력
  static const double xl = 24; // 창 (미니/확장/캡처)
  static const double full = 9999;
}

/// 컴포넌트 치수 (spec §1~2)
abstract class AppSize {
  static const double ringMini = 88; // 두께 12, 안쪽 여백 14
  static const double ringLarge = 160; // 두께 24, 안쪽 여백 28
  static const double ringCompact = 40; // 두께 6
  static const double control = 40; // 알약 높이·원형 버튼
  static const double controlSm = 32;
  static const double row = 56; // 작업 카드
  static const double chip = 32; // 카드 왼쪽 장면 칩
  static const double check = 24;
}

/// 리스트 카드 그림자 (Tiimo식 아주 옅은 6%) — 밤은 null
abstract class AppShadow {
  static List<BoxShadow>? card(Color? c) => c == null
      ? null
      : [BoxShadow(color: c, blurRadius: 8, offset: const Offset(0, 2))];
}

abstract class AppDuration {
  static const press = Duration(milliseconds: 80);
  static const release = Duration(milliseconds: 120);
  static const tab = Duration(milliseconds: 120);
  static const check = Duration(milliseconds: 160);
  static const tick = Duration(milliseconds: 300); // 링 진행 보간
  static const micro = Duration(milliseconds: 150);
  static const enter = Duration(milliseconds: 200);
  static const transition = Duration(milliseconds: 280);
  static const titleSpin = Duration(seconds: 6); // 높은 칭호 테두리 한 바퀴
  static const streakHop = Duration(milliseconds: 1400); // 연속 배너 친구 세 번 뛰기
}

/// 칭호 칸 테두리에 두르는 장식 모양
enum TitleOrnamentShape { dot, leaf, crescent, star, scallop, bubble, ray }

class TitleOrnament {
  const TitleOrnament(this.shape, this.count);
  final TitleOrnamentShape shape;
  final int count;
}

/// 칭호 테두리 한 단계. 장면과 무관한 고정 색 = 칭호의 정체성.
class TitleRing {
  const TitleRing(this.colors,
      {required this.width,
      this.glow = 0,
      this.spin = false,
      this.stars = false,
      this.ornaments = const []});
  final List<Color> colors; // 1색이면 단색, 2색 이상이면 원형 그라데이션
  final double width;
  final double glow; // 바깥 빛 번짐 반경 (0 = 없음)
  final bool spin; // 천천히 회전
  final bool stars; // 링 위 작은 별 3개 (마스터)
  final List<TitleOrnament> ornaments; // 지도 칭호 칸 장식

  /// [base] 색 위에 올릴 글자색: 대비가 큰 쪽
  static Color textOn(Color base) {
    return _contrast(base, TitleRings.ink) >= _contrast(base, TitleRings.star)
        ? TitleRings.ink
        : TitleRings.star;
  }

  static double _contrast(Color a, Color b) {
    final x = a.computeLuminance(), y = b.computeLuminance();
    return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
  }
}

/// FocusTitle.index 순 (씨앗 → 마스터). 숲 녹색 → 달빛 금·라벤더 → 바다 청록 → 금.
abstract class TitleRings {
  static const all = <TitleRing>[
    TitleRing([Color(0xFFB9C2BC)],
        width: 2, ornaments: [TitleOrnament(TitleOrnamentShape.dot, 6)]),
    TitleRing([Color(0xFF8FD3A6)],
        width: 2.5, ornaments: [TitleOrnament(TitleOrnamentShape.leaf, 4)]),
    TitleRing([Color(0xFF52C47C), Color(0xFF8FE2AB)],
        width: 3, ornaments: [TitleOrnament(TitleOrnamentShape.leaf, 8)]),
    TitleRing([Color(0xFF246B4B), Color(0xFF8FE2AB)],
        width: 3, ornaments: [TitleOrnament(TitleOrnamentShape.leaf, 12)]),
    TitleRing([Color(0xFF246B4B), Color(0xFFE3C77F)],
        width: 3.5,
        glow: 6,
        ornaments: [
          TitleOrnament(TitleOrnamentShape.leaf, 8),
          TitleOrnament(TitleOrnamentShape.dot, 8),
        ]),
    TitleRing([Color(0xFFE3C77F), Color(0xFFFFF3C4), Color(0xFFC2B4ED)],
        width: 3.5,
        glow: 8,
        ornaments: [
          TitleOrnament(TitleOrnamentShape.crescent, 4),
          TitleOrnament(TitleOrnamentShape.dot, 8),
        ]),
    TitleRing([Color(0xFFC2B4ED), Color(0xFFE3C77F), Color(0xFF8FA8FF)],
        width: 4,
        glow: 10,
        spin: true,
        ornaments: [TitleOrnament(TitleOrnamentShape.star, 8)]),
    TitleRing([Color(0xFF7CBFE7), Color(0xFF3585BD), Color(0xFF9EE6E0)],
        width: 4,
        glow: 10,
        spin: true,
        ornaments: [TitleOrnament(TitleOrnamentShape.scallop, 14)]),
    TitleRing([Color(0xFF142F40), Color(0xFF3585BD), Color(0xFF9EE6E0)],
        width: 4.5,
        glow: 12,
        spin: true,
        ornaments: [TitleOrnament(TitleOrnamentShape.bubble, 12)]),
    TitleRing([Color(0xFFB98A2E), Color(0xFFFFF3C4), Color(0xFFE3C77F)],
        width: 5,
        glow: 16,
        spin: true,
        stars: true,
        ornaments: [
          TitleOrnament(TitleOrnamentShape.ray, 12),
          TitleOrnament(TitleOrnamentShape.star, 4),
        ]),
  ];
  static const star = Color(0xFFFFFFFF);
  static const ink = Color(0xFF14211B); // 밝은 칭호 색 위 글자
}

/// 폰 레이아웃 치수 (docs/mobile/app-design-spec.md §1~2)
abstract class MobileSize {
  static const double gutter = 20; // 좌우 여백 (SE는 16)
  static const double ring = 232; // 큰 화면 264
  static const double ringSmall = 150; // SE: 스탯 바가 늘어 시간이 가려지지 않게
  static const double ringStroke = 24;
  static const double ringInset = 32;
  static const double row = 48;
  static const double cta = 52;
  static const double statIcon = 22;
  static const double goalBar = 8;
  static const double mapRowHeight = 104;
  static const double mapNode = 64;
  static const double mapNodeBig = 108;
  static const double mapNodeCurrent = 88; // 지금 칸
  static const double mapFutureFade = 0.55; // 아직 안 간 칸·길이 바탕색 쪽으로 옅어지는 비율
  static const double mapZoneTint = 0.26; // 칭호 구간 배경에 칭호 색을 섞는 비율
  static const double mapZoneBlendRows = 3; // 다음 칭호로 넘어가는 배경 그라데이션 길이 (줄)
  static const double mapCheck = 22; // 지나온 칸 체크
  static const double mapPulse = 18; // 지금 칸에서 링이 퍼지는 폭
  static const double mapTitleChip = 42; // 지도 칭호 글자 배지
  static const double mapSwing = 64; // 좌우로 흔들리는 폭
  static const double zoneIcon = 18; // 리그 승급·강등 구분선
  static const double mapLink = 14; // 지나온 길
  static const double mapLinkFuture = 4; // 안 간 길(점선)
  static const double mapLinkOver = 7; // 지나온 길 위에 덧칠하는 줄
  static const double mapLinkDeepen = 0.38; // 밝은 칭호의 지나온 길을 진하게
  static const double mapDash = 7;
  static const double questCard = 88;
  static const double chest = 72;
  static const double chestDot = 12;
  static const double companionLarge = 144;
  static const double leagueIcon = 28;
  static const double leagueIconLarge = 40;
  static const double leagueRank = 28;
  static const double streakIcon = 56;
  static const double streakBannerFriend = 88;
  static const double streakHop = 22; // 친구가 뛰는 높이
  static const double streakDot = 26;
  static const double weekCell = 36;
  static const double taskCard = 72;
  static const double tabBar = 64;
  static const double sheetRadius = 24;
  // iPad: 짧은 변 600 이상이면 태블릿 배치
  static const double tabletBreak = 600;
  static const double listMaxWidth = 720; // 목록 화면 가운데 한 열
  static const double wideMaxWidth = 1100; // 집중·꾸미기 (가로면 두 칸)
  static const double twoPaneBreak = 800; // 이 폭 이상(가로)이면 두 칸
  static const double tabletBase = 640; // iPad 배율 = 짧은 변 / 640 (최대 1.6)
  static const double sidePane = 400; // 두 칸일 때 오른쪽 조작부
  // 간격 규칙 (docs/mobile/review-2.md, astra 여백 리뷰)
  static const double headerMinHeight = 48; // 탭 제목 행
  static const double cardPadding = 16; // 카드 안쪽 (테두리 포함 시각 거리)
  static const double cardGap = 8; // 같은 묶음 카드 사이
  static const double sectionGap = 24; // 다른 묶음 사이
  static const double labelGap = 4; // 라벨–값
  static const double iconGap = 8; // 아이콘–글자
  static const double gridGap = 12;
  static const double contentBottomGap = 24; // 본문 끝–탭바 (탭바 자리는 셸 SafeArea가 이미 비움)
  static const double fieldMinHeight = 56;
  static const double touchMin = 48;
  static const int minMinutes = 10;
  static const int maxMinutes = 180;
  static const int stepMinutes = 5;
  // 칭호 테두리 아바타
  static const double avatar = 56; // 프로필 카드
  static const double avatarRow = 36; // 랭킹 행
  static const double avatarLarge = 96; // 승급·공유·1위
  static const double badge = 24; // 칭호 배지 (행)
  static const double badgeLarge = 34; // 칭호 배지 (프로필·승급)
  static const double ladderDot = 8; // 칭호 사다리 점
}

/// 폰 v3 집중 중 차오름 모션 (docs/v3/app-design-spec.md §5). 전력 예산 때문에 프레임을 제한한다.
abstract class FillMotion {
  static const frame = Duration(milliseconds: 42); // 약 24fps
  static const waveBackAmp = 10.0;
  static const waveBackPeriod = 7.0; // 초
  static const waveOvershoot = 20.0; // 가득 찰 때 물결 골까지 덮는 여유
  static const waveFrontAmp = 6.0;
  static const waveFrontPeriod = 4.0;
  static const iceBob = 3.0; // 얼음이 위아래로 떠다니는 폭
  static const iceBobPeriod = 5.0;
  static const treeSwayDeg = 2.0;
  static const treeSwayPeriod = 6.0;
  static const forestRows = 9; // 아래(가까움)부터 위(멀리)까지 줄
  static const treeNear = 170.0; // 맨 앞 줄 나무 높이 (폭 402 기준)
  static const treeFar = 84.0; // 맨 뒤 줄
  static const treeGrow = 0.2; // 한 그루가 다 자라는 데 걸리는 진행 비율
  static const nightFadeIn = 0.04; // 평소 바탕 → 남색으로 넘어가는 구간
  static const starPeriod = 8.0;
  static const starRadius = 1.8;
  static const starCount = 110;
  static const brightStarEvery = 11; // 이 간격마다 빛나는 큰 별
  static const shootingPeriod = 14.0; // 별똥별 간격 (초)
  static const shootingDuration = 0.9;
  static const waveFarPeriod = 11.0;
  static const rayPeriod = 9.0;
  static const fishSpeed = 16.0; // pt/초
  static const bubbleCount = 16;
  static const bubbleSpeed = 34.0; // pt/초
  static const pollenCount = 18;
  static const leafCount = 8;
  static const leafSpeed = 26.0; // pt/초
}

/// 미니 위젯 / 확장 패널 창 크기 규격 (시안 규격)
abstract class WindowSizes {
  static const mini = Size(320, 128);
  static const expanded = Size(400, 560);
  static const capture = Size(400, 180);
}
