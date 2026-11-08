import ActivityKit
import Foundation

/// 남은 시간 (Live Activity) — 집중·휴식 공용. 이름은 휴식 전용이던 때 그대로. Runner·BreakActivity 두 타깃이 함께 쓴다.
struct BreakAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var endsAt: Date
    var focus: Bool = false
    var title: String = ""
    /// 일시정지면 남은 초 (시계 멈춤), 진행 중이면 nil
    var pausedSec: Int? = nil
  }
}
