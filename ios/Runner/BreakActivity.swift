import ActivityKit
import Flutter
import Foundation

/// 남은 시간 Live Activity(집중·휴식) 시작·종료. 채널: focusone/break
/// start {endsAt: ms, focus, title, pausedSec?} — 이미 떠 있으면 내용만 바꿈 / end
enum BreakActivity {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "focusone/break", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard #available(iOS 16.2, *) else { return result(nil) }
      switch call.method {
      case "start":
        let args = call.arguments as? [String: Any] ?? [:]
        let ms = args["endsAt"] as? Double ?? 0
        start(BreakAttributes.ContentState(
          endsAt: Date(timeIntervalSince1970: ms / 1000),
          focus: args["focus"] as? Bool ?? false,
          title: args["title"] as? String ?? "",
          pausedSec: args["pausedSec"] as? Int))
      case "end":
        end()
      default:
        return result(FlutterMethodNotImplemented)
      }
      result(nil)
    }
  }

  @available(iOS 16.2, *)
  private static func start(_ state: BreakAttributes.ContentState) {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    // 일시정지는 끝나는 시각이 없어 오래 둬도 낡지 않음
    let content = ActivityContent(state: state, staleDate: state.pausedSec == nil ? state.endsAt : nil)
    if let a = Activity<BreakAttributes>.activities.first {
      Task { await a.update(content) }
      return
    }
    _ = try? Activity.request(attributes: BreakAttributes(), content: content)
  }

  @available(iOS 16.2, *)
  private static func end() {
    for a in Activity<BreakAttributes>.activities {
      Task { await a.end(nil, dismissalPolicy: .immediate) }
    }
  }
}
