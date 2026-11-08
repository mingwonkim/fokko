import ActivityKit
import SwiftUI
import WidgetKit

/// 집중·휴식 중: 잠금 화면 + Dynamic Island에 남은 시간 (잠금 화면은 크게)
@main
struct BreakActivityBundle: WidgetBundle {
  var body: some Widget { BreakActivityWidget() }
}

private let green = Color(red: 0x24 / 255, green: 0x6B / 255, blue: 0x4B / 255)
private let mint = Color(red: 0xEE / 255, green: 0xF7 / 255, blue: 0xF1 / 255)

private extension BreakAttributes.ContentState {
  var paused: Bool { pausedSec != nil }
  var icon: String { !focus ? "cup.and.saucer.fill" : (paused ? "pause.fill" : "timer") }
  var head: String { !focus ? "휴식 중" : (paused ? "일시정지" : "집중 중") }
  var sub: String { !focus ? "끝나면 다시 집중해요" : (title.isEmpty ? "다른 앱 말고 이것만" : title) }
  /// 집중: 짙은 초록 바탕 흰 글씨 / 휴식: 민트 바탕 초록 글씨
  var fg: Color { focus ? .white : green }
  var bg: Color { focus ? green : mint }
}

struct BreakActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: BreakAttributes.self) { ctx in
      let s = ctx.state
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Image(systemName: s.icon)
          Text(s.head).fontWeight(.semibold)
          Text(s.sub).lineLimit(1).opacity(0.75)
        }
        .font(.subheadline)
        clock(s)
          .font(.system(size: 64, weight: .bold, design: .rounded))
          .minimumScaleFactor(0.6)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .foregroundStyle(s.fg)
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      .activityBackgroundTint(s.bg)
      .activitySystemActionForegroundColor(s.fg)
    } dynamicIsland: { ctx in
      let s = ctx.state
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label(s.head, systemImage: s.icon).font(.headline).foregroundStyle(.mint)
        }
        DynamicIslandExpandedRegion(.trailing) {
          clock(s).font(.title2.weight(.semibold)).multilineTextAlignment(.trailing)
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text(s.sub).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
      } compactLeading: {
        Image(systemName: s.icon).foregroundStyle(.mint)
      } compactTrailing: {
        clock(s).frame(width: 44).multilineTextAlignment(.trailing).foregroundStyle(.mint)
      } minimal: {
        Image(systemName: s.icon).foregroundStyle(.mint)
      }
    }
  }

  /// 진행 중: 시스템이 직접 줄여 주는 카운트다운 (앱이 꺼져 있어도 흐름) / 일시정지: 멈춘 시각
  private func clock(_ s: BreakAttributes.ContentState) -> Text {
    if let sec = s.pausedSec {
      return Text(String(format: "%d:%02d", sec / 60, sec % 60)).monospacedDigit()
    }
    return Text(timerInterval: Date()...max(s.endsAt, Date()), countsDown: true).monospacedDigit()
  }
}
