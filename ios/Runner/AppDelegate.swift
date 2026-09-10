import Flutter
import UIKit
import UserNotifications
// workmanager hat sich mit 0.10 aufgeteilt: der Apple-Teil steckt jetzt im
// eigenen Paket workmanager_apple, und damit heisst auch das Swift-Modul so.
// Mit dem alten Namen bricht Xcode ab: "Unable to resolve module dependency".
import workmanager_apple

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
    // Dieselben Bezeichner wie in der Info.plist unter
    // BGTaskSchedulerPermittedIdentifiers. Das Plugin verteilt sie an den
    // Dart-callbackDispatcher.
    //
    // Ein gemeinsames registerTask gibt es seit workmanager 0.10 nicht mehr;
    // die Sorte der Aufgabe muss jetzt beim Anmelden benannt werden. Die
    // Bezeichner sagen selbst, welche gemeint ist: App-Refresh wird zu einem
    // BGAppRefreshTaskRequest, die Verarbeitungsaufgabe zu einem
    // BGProcessingTaskRequest.
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "be.tramckrijte.workmanagerExample.iOSBackgroundAppRefresh"
    )
    WorkmanagerPlugin.registerBGProcessingTask(
      withIdentifier: "be.tramckrijte.workmanagerExample.iOSBackgroundProcessingTask"
    )

    // setMinimumBackgroundFetchInterval stand hier als Rueckfallebene fuer
    // iOS 12 und aelter. Seit die Mindestversion auf 14 steht, ist das toter
    // Code -- ab iOS 13 wird der Aufruf ohnehin ignoriert, und Xcode warnt
    // inzwischen darueber. BGTaskScheduler oben macht die Arbeit.

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
