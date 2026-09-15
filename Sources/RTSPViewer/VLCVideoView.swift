import AppKit
import SwiftUI
import VLC

struct VLCVideoView: NSViewRepresentable {
  let player: VLCMediaPlayer

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    view.wantsLayer = true
    view.layer?.backgroundColor = NSColor.black.cgColor
    player.drawable = view
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    if player.drawable == nil {
      player.drawable = nsView
    }
  }

  static func dismantleNSView(_ nsView: NSView, coordinator: Void) {
    nsView.layer = nil
  }
}
