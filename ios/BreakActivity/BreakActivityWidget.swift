import ActivityKit
import SwiftUI
import WidgetKit

/// 집중·휴식 중: 잠금 화면 + Dynamic Island에 남은 시간. 잠금 화면은 앱처럼 장면 색 링, 반투명 장면 바탕.
@main
struct BreakActivityBundle: WidgetBundle {
  var body: some Widget { BreakActivityWidget() }
}

private extension Color {
  init(argb: Int) {
    self.init(.sRGB,
              red: Double((argb >> 16) & 0xFF) / 255,
              green: Double((argb >> 8) & 0xFF) / 255,
              blue: Double(argb & 0xFF) / 255,
              opacity: Double((argb >> 24) & 0xFF) / 255)
  }
}

private extension BreakAttributes.ContentState {
  var paused: Bool { pausedSec != nil }
  var icon: String { !focus ? "cup.and.saucer.fill" : (paused ? "pause.fill" : "timer") }
  var head: String { !focus ? "휴식 중" : (paused ? "일시정지" : "집중 중") }
  /// 할 일 없이 집중하면 nil — 줄을 비운다
  var sub: String? { !focus ? "끝나면 다시 집중해요" : (title.isEmpty ? nil : title) }
  var startedAt: Date { endsAt.addingTimeInterval(-Double(max(totalSec, 1))) }
  /// 앱 링과 같은 방향: 집중은 지난 만큼 차오르고, 휴식은 남은 만큼 남는다
  var pausedFraction: Double {
    guard let sec = pausedSec, totalSec > 0 else { return 0 }
    let left = Double(sec) / Double(totalSec)
    return focus ? 1 - left : left
  }
}

/// 잠금 화면 카드. StandBy(충전 중 가로)에서 화면 전체로 커지면 숫자 중심 배치.
struct LockCard: View {
  let s: BreakAttributes.ContentState
  var body: some View {
    if #available(iOS 17, *) {
      StandByAware(s: s)
    } else {
      CardLayout(s: s, full: false)
    }
  }
}

@available(iOS 17, *)
private struct StandByAware: View {
  let s: BreakAttributes.ContentState
  @Environment(\.isActivityFullscreen) private var full
  var body: some View { CardLayout(s: s, full: full) }
}

private struct CardLayout: View {
  let s: BreakAttributes.ContentState
  let full: Bool
  var body: some View {
    let ring = full ? 128.0 : 100.0
    HStack(spacing: full ? 28 : 16) {
      if full { Spacer(minLength: 0) }
      ZStack {
        Circle().fill(Color(argb: s.card)).padding(ring * 0.09)
        if let img = companionImage(s.companion) {
          Image(uiImage: img).resizable().scaledToFit().padding(ring * 0.2)
        }
        ringView(s, size: ring, width: ring * 0.12)
      }
      .frame(width: ring, height: ring)
      VStack(alignment: .leading, spacing: 0) {
        Label(s.head, systemImage: s.icon)
          .font(.subheadline.weight(.bold))
          .foregroundStyle(Color(argb: s.ring))
        clock(s)
          .font(.system(size: full ? 84 : 60, weight: .heavy, design: .rounded))
          .minimumScaleFactor(0.5)
          .lineLimit(1)
        if !full, let sub = s.sub {
          Text(sub).font(.subheadline.weight(.semibold)).lineLimit(1)
        }
      }
      Spacer(minLength: 0)
    }
    .foregroundStyle(Color(argb: s.text))
  }
}

struct BreakActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: BreakAttributes.self) { ctx in
      let s = ctx.state
      LockCard(s: s)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        // 잠금 화면 배경이 살짝 비치되 글자·링은 또렷하게 (0.55는 바다·숲에서 숫자가 묻혔음: 실사용 11/08)
        .activityBackgroundTint(Color(argb: s.card).opacity(0.8))
        .activitySystemActionForegroundColor(Color(argb: s.text))
    } dynamicIsland: { ctx in
      let s = ctx.state
      let tint = Color(argb: s.ring)
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label(s.head, systemImage: s.icon).font(.headline).foregroundStyle(tint)
        }
        DynamicIslandExpandedRegion(.trailing) {
          clock(s).font(.title2.weight(.semibold)).multilineTextAlignment(.trailing)
        }
        DynamicIslandExpandedRegion(.bottom) {
          if let sub = s.sub {
            Text(sub).font(.caption).foregroundStyle(.secondary).lineLimit(1)
          }
        }
      } compactLeading: {
        badge(s, size: 26)
      } compactTrailing: {
        clock(s).frame(width: 44).multilineTextAlignment(.trailing).foregroundStyle(tint)
      } minimal: {
        badge(s, size: 36)
      }
    }
  }
}

func companionImage(_ id: String) -> UIImage? {
  guard !id.isEmpty,
        let path = Bundle.main.path(forResource: id, ofType: "png", inDirectory: "companions")
  else { return nil }
  return UIImage(contentsOfFile: path)
}

/// 진행 중: 시스템이 직접 줄여 주는 카운트다운 (앱이 꺼져 있어도 흐름) / 일시정지: 멈춘 시각
func clock(_ s: BreakAttributes.ContentState) -> Text {
  if let sec = s.pausedSec {
    return Text(String(format: "%d:%02d", sec / 60, sec % 60)).monospacedDigit()
  }
  return Text(timerInterval: Date()...max(s.endsAt, Date()), countsDown: true).monospacedDigit()
}

/// 작은 칸(StandBy 위 원·다이내믹 아일랜드)용: 칸을 꽉 채운 굵은 링 + 캐릭터 — 한눈에 Fokko로 보이고 눌러 펼치게
func badge(_ s: BreakAttributes.ContentState, size: CGFloat) -> some View {
  ZStack {
    if let img = companionImage(s.companion) {
      Image(uiImage: img).resizable().scaledToFit().padding(size * 0.15)
    }
    ringView(s, size: size, width: size * 0.13)
    // 눌러서 펼친다는 표시 — 원 밖엔 그릴 수 없어 오른쪽 아래에 겹친다
    Image(systemName: "arrow.down.right")
      .font(.system(size: size * 0.2, weight: .heavy))
      .foregroundStyle(.black)
      .frame(width: size * 0.4, height: size * 0.4)
      .background(Circle().fill(Color(argb: s.ring)))
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
  }
  .frame(width: size, height: size)
}

/// 앱의 굵은 링. 진행 중엔 시스템 타이머 링이라 앱이 꺼져 있어도 차오른다.
@ViewBuilder
func ringView(_ s: BreakAttributes.ContentState, size: CGFloat, width: CGFloat) -> some View {
  let color = Color(argb: s.ring)
  ZStack {
    if s.paused || s.totalSec <= 0 {
      Circle().stroke(color.opacity(0.22), lineWidth: width) // 시스템 타이머 링의 바탕과 비슷하게
      Circle()
        .trim(from: 0, to: s.pausedFraction)
        .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
        .rotationEffect(.degrees(-90))
    } else {
      ProgressView(timerInterval: s.startedAt...max(s.endsAt, s.startedAt.addingTimeInterval(1)),
                   countsDown: !s.focus,
                   label: { EmptyView() },
                   currentValueLabel: { EmptyView() })
        .progressViewStyle(.circular)
        .tint(color) // 바탕 원은 시스템이 tint로 그린다
    }
  }
  .frame(width: size, height: size)
}
