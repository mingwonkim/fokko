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

struct BreakActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: BreakAttributes.self) { ctx in
      let s = ctx.state
      let text = Color(argb: s.text)
      HStack(spacing: 18) {
        ZStack {
          Circle().fill(Color(argb: s.card)).padding(10)
          if let img = companionImage(s.companion) {
            Image(uiImage: img).resizable().scaledToFit().padding(22)
          }
          ring(s, size: 118, width: 12)
        }
        .frame(width: 118, height: 118)
        VStack(alignment: .leading, spacing: 2) {
          Label(s.head, systemImage: s.icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color(argb: s.ring))
          clock(s)
            .font(.system(size: 46, weight: .bold, design: .rounded))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
          if let sub = s.sub {
            Text(sub).font(.subheadline.weight(.semibold)).lineLimit(1).opacity(0.85)
          }
        }
        Spacer(minLength: 0)
      }
      .foregroundStyle(text)
      .padding(16)
      .activityBackgroundTint(Color(argb: s.card).opacity(0.55))
      .activitySystemActionForegroundColor(text)
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
        ring(s, size: 20, width: 3)
      } compactTrailing: {
        clock(s).frame(width: 44).multilineTextAlignment(.trailing).foregroundStyle(tint)
      } minimal: {
        ring(s, size: 20, width: 3)
      }
    }
  }

  private func companionImage(_ id: String) -> UIImage? {
    guard !id.isEmpty,
          let path = Bundle.main.path(forResource: id, ofType: "png", inDirectory: "companions")
    else { return nil }
    return UIImage(contentsOfFile: path)
  }

  /// 진행 중: 시스템이 직접 줄여 주는 카운트다운 (앱이 꺼져 있어도 흐름) / 일시정지: 멈춘 시각
  private func clock(_ s: BreakAttributes.ContentState) -> Text {
    if let sec = s.pausedSec {
      return Text(String(format: "%d:%02d", sec / 60, sec % 60)).monospacedDigit()
    }
    return Text(timerInterval: Date()...max(s.endsAt, Date()), countsDown: true).monospacedDigit()
  }

  /// 앱의 굵은 링. 진행 중엔 시스템 타이머 링이라 앱이 꺼져 있어도 차오른다.
  @ViewBuilder
  private func ring(_ s: BreakAttributes.ContentState, size: CGFloat, width: CGFloat) -> some View {
    let color = Color(argb: s.ring)
    ZStack {
      if s.paused || s.totalSec <= 0 {
        Circle().stroke(Color(argb: s.track), lineWidth: width)
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
}
