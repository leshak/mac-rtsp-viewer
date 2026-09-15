import Foundation
import Observation
import VLC

@Observable
@MainActor
final class StreamViewModel {
  let player = VLCMediaPlayer()

  private(set) var streamURL: String
  private(set) var status: PlaybackStatus = .idle
  private(set) var playbackError: PlaybackError?

  private let defaults: UserDefaults
  private let streamURLKey = "streamURL"
  @ObservationIgnored private var stateTask: Task<Void, Never>?

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    streamURL = defaults.string(forKey: streamURLKey) ?? ""
  }

  deinit {
    stateTask?.cancel()
  }

  var streamHost: String? {
    guard let url = URL(string: streamURL), let host = url.host else {
      return nil
    }

    if let port = url.port {
      return "\(host):\(port)"
    }

    return host
  }

  func play() {
    player.stop()
    playbackError = nil

    guard let url = validatedURL(from: streamURL) else {
      status = .failed
      playbackError = .missingURL
      return
    }

    let media = VLCMedia(url: url)
    media.addOptions([
      "network-caching": 300,
      "rtsp-tcp": true,
    ])
    player.media = media
    status = .connecting
    player.play()
    startStateMonitoring()
  }

  func stop() {
    stateTask?.cancel()
    stateTask = nil
    player.stop()
    status = .idle
    playbackError = nil
  }

  @discardableResult
  func saveStreamURL(_ value: String) -> Bool {
    let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

    guard validatedURL(from: trimmedValue) != nil else {
      return false
    }

    streamURL = trimmedValue
    defaults.set(trimmedValue, forKey: streamURLKey)
    play()
    return true
  }

  func clearStreamURL() {
    defaults.removeObject(forKey: streamURLKey)
    streamURL = ""
    stop()
  }

  func validatedURL(from value: String) -> URL? {
    guard
      let url = URL(string: value),
      let scheme = url.scheme?.lowercased(),
      ["rtsp", "rtsps"].contains(scheme),
      url.host != nil
    else {
      return nil
    }

    return url
  }

  private func startStateMonitoring() {
    stateTask?.cancel()
    stateTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(200))
        guard let self, !Task.isCancelled else { return }
        refreshPlaybackStatus()
      }
    }
  }

  private func refreshPlaybackStatus() {
    if player.hasVideoOut {
      status = .playing
      playbackError = nil
      return
    }

    switch player.state {
    case .opening, .buffering:
      status = .connecting
    case .playing, .esAdded:
      status = .playing
      playbackError = nil
    case .error:
      status = .failed
      playbackError = .cameraUnavailable
    case .stopped, .ended, .paused:
      if status != .failed {
        status = .idle
      }
    @unknown default:
      break
    }
  }
}

enum PlaybackStatus: Equatable {
  case idle
  case connecting
  case playing
  case failed
}

enum PlaybackError: Equatable {
  case missingURL
  case cameraUnavailable
}
