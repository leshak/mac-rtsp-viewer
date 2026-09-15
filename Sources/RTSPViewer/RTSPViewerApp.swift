import AppKit

@main
@MainActor
struct RTSPViewerApplication {
  static func main() {
    let application = NSApplication.shared
    let delegate = AppDelegate()

    application.delegate = delegate
    application.setActivationPolicy(.accessory)

    withExtendedLifetime(delegate) {
      application.run()
    }
  }
}
