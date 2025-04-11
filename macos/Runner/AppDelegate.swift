import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  // Handle URL scheme redirects
  override func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
      let urlString = url.absoluteString
      print("Received URL: \(urlString)")
      
      // Get the Flutter view controller
      if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
        // Create a method channel to communicate with Dart
        let channel = FlutterMethodChannel(
          name: "app.mastodon/url_handler",
          binaryMessenger: controller.engine.binaryMessenger
        )
        
        // Call our custom method
        channel.invokeMethod("handleUrl", arguments: urlString)
      }
    }
  }
}
