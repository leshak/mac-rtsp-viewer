import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  private let viewModel = StreamViewModel()
  private let localization = LocalizationManager()
  private let activationHook = ActivationHookModel()
  private var statusItem: NSStatusItem?
  private var mainWindow: NSWindow?
  private var debugLogWindow: NSWindow?
  private var statusMenu = NSMenu()

  func applicationDidFinishLaunching(_ notification: Notification) {
    localization.onLanguageChange = { [weak self] in
      self?.refreshLocalizedMenus()
    }
    statusMenu = makeStatusMenu()
    configureApplicationMenu()
    configureStatusItem()
    createMainWindow()
    configureActivationHook()

    if ProcessInfo.processInfo.arguments.contains("--show-window") {
      showMainWindow()
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    activationHook.stop()
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  func windowWillClose(_ notification: Notification) {
    activationHook.cancelPendingClose()
    viewModel.stop()
  }

  @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
    if NSApp.currentEvent?.type == .rightMouseUp {
      statusMenu.popUp(
        positioning: nil,
        at: NSPoint(x: 0, y: sender.bounds.height + 2),
        in: sender
      )
      return
    }

    toggleMainWindow()
  }

  @objc private func showMainWindowFromMenu(_ sender: Any?) {
    showMainWindow()
  }

  @objc private func quitApplication(_ sender: Any?) {
    NSApp.terminate(sender)
  }

  private func configureStatusItem() {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    if let button = item.button {
      let image = NSImage(
        systemSymbolName: "video.fill",
        accessibilityDescription: "RTSP Viewer"
      )
      image?.isTemplate = true

      button.image = image
      button.imagePosition = .imageOnly
      button.toolTip = "RTSP Viewer"
      button.target = self
      button.action = #selector(statusItemClicked(_:))
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    statusItem = item
  }

  private func createMainWindow() {
    let contentView = ContentView(
      viewModel: viewModel,
      activationHook: activationHook,
      localization: localization
    )
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 960, height: 600),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )

    window.title = "RTSP Viewer"
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.isMovableByWindowBackground = true
    window.isReleasedWhenClosed = false
    window.minSize = NSSize(width: 640, height: 400)
    window.collectionBehavior = [.fullScreenPrimary]
    window.contentView = NSHostingView(rootView: contentView)
    window.delegate = self
    window.center()
    // Frame restoration includes the saved display, so register autosaving after centering.
    window.setFrameAutosaveName("RTSPViewer.MainWindow")

    mainWindow = window
  }

  private func toggleMainWindow() {
    guard let mainWindow else { return }

    if mainWindow.isVisible, !mainWindow.isMiniaturized {
      hideMainWindow()
    } else {
      showMainWindow()
    }
  }

  private func showMainWindow(cancelHookTimeout: Bool = true) {
    guard let mainWindow else { return }
    let shouldStartPlayback = !mainWindow.isVisible

    if cancelHookTimeout {
      activationHook.cancelPendingClose()
    }

    if mainWindow.isMiniaturized {
      mainWindow.deminiaturize(nil)
    }

    NSApp.activate(ignoringOtherApps: true)
    mainWindow.makeKeyAndOrderFront(nil)
    if shouldStartPlayback {
      viewModel.play()
    }
  }

  private func hideMainWindow(cancelHookTimeout: Bool = true) {
    if cancelHookTimeout {
      activationHook.cancelPendingClose()
    }

    mainWindow?.orderOut(nil)
    viewModel.stop()
  }

  private func configureActivationHook() {
    activationHook.onShowRequested = { [weak self] in
      self?.showMainWindow(cancelHookTimeout: false)
    }
    activationHook.onHideRequested = { [weak self] in
      self?.hideMainWindow(cancelHookTimeout: false)
    }
    activationHook.onDebugLoggingChange = { [weak self] isEnabled in
      if isEnabled {
        self?.showDebugLogWindow()
      } else {
        self?.debugLogWindow?.orderOut(nil)
      }
    }

    activationHook.start()
    if activationHook.isDebugLoggingEnabled {
      showDebugLogWindow()
    }
  }

  private func showDebugLogWindow() {
    if debugLogWindow == nil {
      let logView = ActivationHookLogView(model: activationHook, localization: localization)
      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 720, height: 420),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
      )
      window.title = localization.string(.incomingRequestLog)
      window.isReleasedWhenClosed = false
      window.minSize = NSSize(width: 520, height: 260)
      window.contentView = NSHostingView(rootView: logView)
      window.center()
      window.setFrameAutosaveName("RTSPViewer.ActivationHookLogWindow")
      debugLogWindow = window
    }

    guard let debugLogWindow else { return }
    if debugLogWindow.isMiniaturized {
      debugLogWindow.deminiaturize(nil)
    }
    NSApp.activate(ignoringOtherApps: true)
    debugLogWindow.makeKeyAndOrderFront(nil)
  }

  private func makeStatusMenu() -> NSMenu {
    let menu = NSMenu()

    let openItem = NSMenuItem(
      title: localization.string(.openViewer),
      action: #selector(showMainWindowFromMenu(_:)),
      keyEquivalent: ""
    )
    openItem.target = self
    menu.addItem(openItem)
    menu.addItem(.separator())

    let quitItem = NSMenuItem(
      title: localization.string(.quitViewer),
      action: #selector(quitApplication(_:)),
      keyEquivalent: "q"
    )
    quitItem.target = self
    menu.addItem(quitItem)

    return menu
  }

  private func configureApplicationMenu() {
    let mainMenu = NSMenu()
    let applicationItem = NSMenuItem()
    let applicationMenu = NSMenu()

    let quitItem = NSMenuItem(
      title: localization.string(.quitViewer),
      action: #selector(quitApplication(_:)),
      keyEquivalent: "q"
    )
    quitItem.target = self
    applicationMenu.addItem(quitItem)
    applicationItem.submenu = applicationMenu
    mainMenu.addItem(applicationItem)

    let editItem = NSMenuItem()
    let editMenu = NSMenu(title: localization.string(.edit))
    editMenu.addItem(
      menuItem(title: localization.string(.undo), action: Selector(("undo:")), key: "z"))
    editMenu.addItem(
      menuItem(
        title: localization.string(.redo), action: Selector(("redo:")), key: "z", shift: true
      ))
    editMenu.addItem(.separator())
    editMenu.addItem(
      menuItem(title: localization.string(.cut), action: #selector(NSText.cut(_:)), key: "x"))
    editMenu.addItem(
      menuItem(title: localization.string(.copy), action: #selector(NSText.copy(_:)), key: "c"))
    editMenu.addItem(
      menuItem(title: localization.string(.paste), action: #selector(NSText.paste(_:)), key: "v"))
    editMenu.addItem(
      menuItem(
        title: localization.string(.selectAll), action: #selector(NSText.selectAll(_:)), key: "a"))
    editItem.submenu = editMenu
    mainMenu.addItem(editItem)

    NSApp.mainMenu = mainMenu
  }

  private func refreshLocalizedMenus() {
    statusMenu = makeStatusMenu()
    configureApplicationMenu()
    debugLogWindow?.title = localization.string(.incomingRequestLog)
  }

  private func menuItem(title: String, action: Selector, key: String, shift: Bool = false)
    -> NSMenuItem
  {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
    item.keyEquivalentModifierMask = shift ? [.command, .shift] : [.command]
    return item
  }
}
