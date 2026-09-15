import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  private let viewModel = StreamViewModel()
  private var statusItem: NSStatusItem?
  private var mainWindow: NSWindow?
  private lazy var statusMenu = makeStatusMenu()

  func applicationDidFinishLaunching(_ notification: Notification) {
    configureApplicationMenu()
    configureStatusItem()
    createMainWindow()

    if ProcessInfo.processInfo.arguments.contains("--show-window") {
      showMainWindow()
    }
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  func windowWillClose(_ notification: Notification) {
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
    let contentView = ContentView(viewModel: viewModel)
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
    window.setFrameAutosaveName("RTSPViewer.MainWindow")
    window.center()

    mainWindow = window
  }

  private func toggleMainWindow() {
    guard let mainWindow else { return }

    if mainWindow.isVisible, !mainWindow.isMiniaturized {
      mainWindow.orderOut(nil)
      viewModel.stop()
    } else {
      showMainWindow()
    }
  }

  private func showMainWindow() {
    guard let mainWindow else { return }

    if mainWindow.isMiniaturized {
      mainWindow.deminiaturize(nil)
    }

    NSApp.activate(ignoringOtherApps: true)
    mainWindow.makeKeyAndOrderFront(nil)
    viewModel.play()
  }

  private func makeStatusMenu() -> NSMenu {
    let menu = NSMenu()

    let openItem = NSMenuItem(
      title: "Открыть RTSP Viewer",
      action: #selector(showMainWindowFromMenu(_:)),
      keyEquivalent: ""
    )
    openItem.target = self
    menu.addItem(openItem)
    menu.addItem(.separator())

    let quitItem = NSMenuItem(
      title: "Завершить RTSP Viewer",
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
      title: "Завершить RTSP Viewer",
      action: #selector(quitApplication(_:)),
      keyEquivalent: "q"
    )
    quitItem.target = self
    applicationMenu.addItem(quitItem)
    applicationItem.submenu = applicationMenu
    mainMenu.addItem(applicationItem)

    let editItem = NSMenuItem()
    let editMenu = NSMenu(title: "Правка")
    editMenu.addItem(menuItem(title: "Отменить", action: Selector(("undo:")), key: "z"))
    editMenu.addItem(
      menuItem(title: "Повторить", action: Selector(("redo:")), key: "z", shift: true))
    editMenu.addItem(.separator())
    editMenu.addItem(menuItem(title: "Вырезать", action: #selector(NSText.cut(_:)), key: "x"))
    editMenu.addItem(menuItem(title: "Копировать", action: #selector(NSText.copy(_:)), key: "c"))
    editMenu.addItem(menuItem(title: "Вставить", action: #selector(NSText.paste(_:)), key: "v"))
    editMenu.addItem(
      menuItem(title: "Выбрать всё", action: #selector(NSText.selectAll(_:)), key: "a"))
    editItem.submenu = editMenu
    mainMenu.addItem(editItem)

    NSApp.mainMenu = mainMenu
  }

  private func menuItem(title: String, action: Selector, key: String, shift: Bool = false)
    -> NSMenuItem
  {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
    item.keyEquivalentModifierMask = shift ? [.command, .shift] : [.command]
    return item
  }
}
