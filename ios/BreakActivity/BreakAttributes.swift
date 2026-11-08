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
    /// 링 한 바퀴 = 이 세션(휴식) 전체 길이
    var totalSec: Int = 0
    /// 장면 색 ARGB — 앱의 FocusScene 그대로 (링·링 바탕·카드 바탕·글자)
    var ring: Int = 0xFF4F8D6D
    var track: Int = 0xFFDCEEE3
    var card: Int = 0xFFEEF7F1
    var text: Int = 0xFF162D22
    /// 데려올 친구 id — 확장 번들 companions/<id>.png (빌드 단계 Copy Companions가 앱 애셋에서 만든다)
    var companion: String = ""
  }
}
