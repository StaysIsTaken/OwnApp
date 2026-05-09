import Flutter
import UIKit
import UserNotifications
import workmanager

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // ───────── Local Notifications ─────────
    // Sets the FlutterAppDelegate as the UNUserNotificationCenter delegate
    // so notifications can be shown while the app is in the foreground.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    // ───────── Workmanager (Background Tasks) ─────────
    // Register the same identifiers that we listed in Info.plist under
    // BGTaskSchedulerPermittedIdentifiers. The workmanager plugin handles
    // dispatching these to the Dart callbackDispatcher.
    WorkmanagerPlugin.registerTask(
      withIdentifier: "be.tramckrijte.workmanagerExample.iOSBackgroundAppRefresh"
    )
    WorkmanagerPlugin.registerTask(
      withIdentifier: "be.tramckrijte.workmanagerExample.iOSBackgroundProcessingTask"
    )

    // (Optional) Periodic background fetch – older iOS API, kept as fallback
    // for iOS 12 and below. iOS 13+ uses the BGTaskScheduler above.
    UIApplication.shared.setMinimumBackgroundFetchInterval(
      TimeInterval(60 * 60 * 6) // 6 hours
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
