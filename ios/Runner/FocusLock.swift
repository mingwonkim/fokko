import DeviceActivity
import FamilyControls
import Flutter
import ManagedSettings
import SwiftUI
import UIKit

/// 집중 중 앱 잠금 (Family Controls). 채널: focusone/lock
/// - 선택한 앱 목록·진행 세션 ID·해제 예약 이름은 App Group에 저장 → FocusMonitor 확장이 Flutter 없이 해제한다.
/// - DeviceActivity 최소 감시 구간 15분 → 15분 미만 세션은 잠그지 않는다(Dart 쪽에서 막음).
final class FocusLock: NSObject, FlutterPlugin {
  static let group = "group.com.looinlabs.focusone"
  static let store = ManagedSettingsStore(named: .init("focusone"))
  private let center = DeviceActivityCenter()
  private var defaults: UserDefaults { UserDefaults(suiteName: Self.group)! }

  /// 15분 제한 비교 허용 오차 (Dart FocusLockService.minLock과 같게)
  static let minLockSec: TimeInterval = 15 * 60 - 10

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "focusone/lock", binaryMessenger: registrar.messenger())
    let lock = FocusLock()
    lock.cleanupExpired()
    registrar.addMethodCallDelegate(lock, channel: channel)
  }

  /// 종료 시각이 지났는데 잠금이 남아 있으면 정리 (확장 콜백이 누락된 경우 대비)
  func cleanupExpired() {
    let endsAt = defaults.double(forKey: "endsAt")
    if endsAt > 0 && endsAt <= Date().timeIntervalSince1970 { stop() }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "status":
      cleanupExpired()
      result([
        "authorized": AuthorizationCenter.shared.authorizationStatus == .approved,
        "selectedCount": selectionCount(loadSelection()),
      ])
    case "authorize":
      Task { @MainActor in
        do {
          try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
          result(true)
        } catch {
          result(false)
        }
      }
    case "pickApps":
      presentPicker(result: result)
    case "start":
      guard let sessionId = args["sessionId"] as? String,
            let endsAtMs = args["endsAtMs"] as? Int else {
        return result(FlutterError(code: "args", message: "sessionId, endsAtMs 필요", details: nil))
      }
      result(start(sessionId: sessionId, endsAt: Date(timeIntervalSince1970: Double(endsAtMs) / 1000)))
    case "stop":
      stop()
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: 선택 앱 저장
  private func loadSelection() -> FamilyActivitySelection {
    guard let data = defaults.data(forKey: "selection"),
          let sel = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
    else { return FamilyActivitySelection() }
    return sel
  }

  private func saveSelection(_ sel: FamilyActivitySelection) {
    defaults.set(try? PropertyListEncoder().encode(sel), forKey: "selection")
  }

  private func selectionCount(_ s: FamilyActivitySelection) -> Int {
    s.applicationTokens.count + s.categoryTokens.count + s.webDomainTokens.count
  }

  private func presentPicker(result: @escaping FlutterResult) {
    let model = PickerModel(selection: loadSelection())
    let host = UIHostingController(rootView: PickerSheet(model: model) { [weak self] sel in
      self?.saveSelection(sel)
      result(self?.selectionCount(sel) ?? 0)
    })
    let root = UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }.first
    var top = root
    while let p = top?.presentedViewController { top = p }
    top?.present(host, animated: true)
  }

  // MARK: 잠금 시작/해제
  private func start(sessionId: String, endsAt: Date) -> Bool {
    let sel = loadSelection()
    guard selectionCount(sel) > 0, endsAt.timeIntervalSinceNow >= Self.minLockSec else { return false }
    // 앱 재실행으로 같은 잠금을 다시 걸면 예약은 그대로 둔다 — stopMonitoring이 확장의 intervalDidEnd를
    // 불러 방금 건 잠금까지 풀어 버렸음 (재실행할 때마다 잠금 풀림: 실사용 11/08)
    if defaults.string(forKey: "activeSessionId") == sessionId,
       abs(defaults.double(forKey: "endsAt") - endsAt.timeIntervalSince1970) < 60 {
      Self.applyShield(sel)
      return true
    }
    // 예약 이름을 바꿔 먼저 저장 → 아래 stopMonitoring이 부르는 지난 예약의 intervalDidEnd는 이름이 달라 무시된다
    let activity = "focus.\(sessionId).\(Int(endsAt.timeIntervalSince1970))"
    defaults.set(activity, forKey: "activeActivity")
    center.stopMonitoring() // 이전 세션 예약 제거 → 오래된 콜백이 새 잠금을 풀지 못함
    let cal = Calendar.current
    let comps: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
    let schedule = DeviceActivitySchedule(
      intervalStart: cal.dateComponents(comps, from: Date()),
      intervalEnd: cal.dateComponents(comps, from: endsAt),
      repeats: false)
    // 해제 예약이 먼저 — 예약이 성공한 뒤에만 잠근다(그 사이 앱이 죽어도 '잠금만 남는' 상태가 없게)
    do {
      try center.startMonitoring(.init(activity), during: schedule)
    } catch {
      stop() // 지난 예약도 지웠으니 남은 잠금도 푼다
      return false
    }
    defaults.set(sessionId, forKey: "activeSessionId")
    defaults.set(endsAt.timeIntervalSince1970, forKey: "endsAt")
    Self.applyShield(sel)
    return true
  }

  private func stop() {
    defaults.removeObject(forKey: "activeActivity")
    center.stopMonitoring()
    defaults.removeObject(forKey: "activeSessionId")
    defaults.removeObject(forKey: "endsAt")
    Self.store.clearAllSettings()
  }

  static func applyShield(_ sel: FamilyActivitySelection) {
    store.shield.applications = sel.applicationTokens.isEmpty ? nil : sel.applicationTokens
    store.shield.applicationCategories = sel.categoryTokens.isEmpty ? nil : .specific(sel.categoryTokens)
    store.shield.webDomains = sel.webDomainTokens.isEmpty ? nil : sel.webDomainTokens
  }
}

final class PickerModel: ObservableObject {
  @Published var selection: FamilyActivitySelection
  init(selection: FamilyActivitySelection) { self.selection = selection }
}

struct PickerSheet: View {
  @ObservedObject var model: PickerModel
  let onDone: (FamilyActivitySelection) -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      FamilyActivityPicker(selection: $model.selection)
        .navigationTitle("집중 중 잠글 앱")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("완료") { onDone(model.selection); dismiss() }
          }
        }
    }
  }
}
