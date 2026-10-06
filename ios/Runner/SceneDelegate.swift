import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  /// Covers the UI while the scene is inactive/backgrounded so patient names,
  /// addresses and order details never appear in the app-switcher snapshot.
  /// Driven by UIScene notifications (not by overriding the lifecycle
  /// callbacks) so FlutterSceneDelegate's own lifecycle forwarding to the
  /// engine is left untouched.
  private var privacyOverlay: UIView?
  private var lifecycleObservers: [NSObjectProtocol] = []

  override init() {
    super.init()
    let center = NotificationCenter.default
    lifecycleObservers = [
      center.addObserver(forName: UIScene.willDeactivateNotification, object: nil, queue: .main) {
        [weak self] note in self?.showPrivacyOverlay(for: note.object as? UIWindowScene)
      },
      center.addObserver(forName: UIScene.didEnterBackgroundNotification, object: nil, queue: .main) {
        [weak self] note in self?.showPrivacyOverlay(for: note.object as? UIWindowScene)
      },
      center.addObserver(forName: UIScene.didActivateNotification, object: nil, queue: .main) {
        [weak self] _ in self?.hidePrivacyOverlay()
      },
    ]
  }

  deinit {
    lifecycleObservers.forEach(NotificationCenter.default.removeObserver)
  }

  private func showPrivacyOverlay(for scene: UIWindowScene?) {
    guard privacyOverlay == nil,
          let window = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first
    else { return }

    // Reuse the launch screen so the snapshot shows the app's branding.
    let overlay = UIStoryboard(name: "LaunchScreen", bundle: nil)
      .instantiateInitialViewController()?.view ?? UIView()
    overlay.backgroundColor = overlay.backgroundColor ?? .systemBackground
    overlay.frame = window.bounds
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    overlay.isUserInteractionEnabled = false
    window.addSubview(overlay)
    privacyOverlay = overlay
  }

  private func hidePrivacyOverlay() {
    privacyOverlay?.removeFromSuperview()
    privacyOverlay = nil
  }
}
