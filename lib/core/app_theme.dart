// lib/core/app_theme.dart
import 'package:material_ui/material_ui.dart';
import 'design_tokens.dart';

/// Apple HIG 스타일 테마.
/// 폰트는 시스템 기본을 사용한다 — macOS에서는 자동으로 SF가 적용되고,
/// Windows/Linux에서는 각 OS 기본 폰트에 SF 스케일(음수 자간)을 입힌다.
/// 위젯 스타일은 최대한 여기(컴포넌트 테마)에서 처리해 화면 코드를 단순하게 유지한다.
abstract class AppTheme {
  /// 장면(숲/밤/바다)별 테마 — 값은 전부 SceneStyle(시안 추출값)에서 파생
  static ThemeData of(FocusScene scene) {
    final s = scene.style;
    return _base(
      colorScheme: ColorScheme(
        brightness: s.brightness,
        primary: s.accent,
        onPrimary: s.checkFg,
        secondary: s.accent,
        onSecondary: s.checkFg,
        surface: s.rowBg, // 팝업 메뉴·팝오버 바탕
        onSurface: s.textStrong,
        onSurfaceVariant: s.textMuted,
        outline: s.divider,
        error: AppColors.error,
        onError: AppColors.onPrimary,
      ),
      fieldFill: s.fieldFill,
    );
  }

  static ThemeData _base({
    required ColorScheme colorScheme,
    required Color fieldFill,
  }) {
    // SF Pro 스케일: 17/15/13pt + 음수 자간
    const textTheme = TextTheme(
      headlineLarge: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -0.8),
      headlineMedium: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w600, height: 1.3, letterSpacing: -0.6),
      titleMedium: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w600, height: 1.35, letterSpacing: -0.4),
      bodyLarge: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w400, height: 1.4, letterSpacing: -0.4),
      bodyMedium: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w400, height: 1.45, letterSpacing: -0.2),
      bodySmall: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w400, height: 1.4, letterSpacing: -0.1),
      labelLarge: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w500, height: 1.4, letterSpacing: -0.2),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      // frameless 창의 라운드 코너를 위해 Scaffold는 투명 처리
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: textTheme,
      splashFactory: NoSplash.splashFactory, // 잉크 스플래시 제거 — 애플식 절제
      highlightColor: colorScheme.onSurface.withValues(alpha: 0.06),
      hoverColor: colorScheme.onSurface.withValues(alpha: 0.04),

      // 필 형태 채움 버튼 (iOS 스타일)
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 10),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          side: BorderSide(color: colorScheme.outline, width: 0.5),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 10),
          textStyle: textTheme.labelLarge,
          foregroundColor: colorScheme.primary,
        ),
      ),

      // 테두리 없는 회색 필드 (iOS 검색창 스타일)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        hintStyle:
            textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
      ),

      // 필 형태 칩 (타이머 길이 선택)
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: colorScheme.outline, width: 0.5),
        backgroundColor: Colors.transparent,
        selectedColor: colorScheme.primary,
        showCheckmark: false,
        labelStyle: textTheme.bodySmall,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      // 0.5px 헤어라인 디바이더
      dividerTheme: DividerThemeData(
        color: colorScheme.outline,
        thickness: 0.5,
        space: 0.5,
      ),

      tabBarTheme: TabBarThemeData(
        dividerHeight: 0,
        labelStyle: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: textTheme.bodyMedium,
        indicatorSize: TabBarIndicatorSize.label,
      ),
    );
  }
}
