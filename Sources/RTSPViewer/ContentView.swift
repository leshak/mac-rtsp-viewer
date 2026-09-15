import SwiftUI

struct ContentView: View {
  @Bindable var viewModel: StreamViewModel
  @Bindable var activationHook: ActivationHookModel
  @Bindable var localization: LocalizationManager
  @State private var isSettingsPresented = false

  var body: some View {
    ZStack {
      Color.black

      VLCVideoView(player: viewModel.player)
        .frame(maxWidth: .infinity, maxHeight: .infinity)

      if let playbackError = viewModel.playbackError {
        errorOverlay(message: localization.playbackError(playbackError))
      }

      VStack(spacing: 0) {
        topBar

        if viewModel.isDateTimeVisible {
          HStack {
            dateTimeOverlay
            Spacer()
          }
          .padding(.leading, 16)
          .padding(.top, 12)
        }

        Spacer()
        bottomBar
      }
    }
    .ignoresSafeArea()
    .sheet(isPresented: $isSettingsPresented) {
      SettingsView(
        viewModel: viewModel,
        activationHook: activationHook,
        localization: localization
      )
    }
  }

  private var topBar: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text("RTSP Viewer")
          .font(.headline)
        Text(viewModel.streamHost ?? localization.string(.rtspNotConfigured))
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      HStack(spacing: 2) {
        Button {
          viewModel.toggleMute()
        } label: {
          Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
            .font(.system(size: 14, weight: .semibold))
            .frame(width: 30, height: 30)
        }
        .buttonStyle(.borderless)
        .help(muteActionTitle)
        .accessibilityLabel(muteActionTitle)

        Button {
          isSettingsPresented = true
        } label: {
          Image(systemName: "gearshape.fill")
            .font(.system(size: 14, weight: .semibold))
            .frame(width: 30, height: 30)
        }
        .buttonStyle(.borderless)
        .help(localization.string(.settings))
        .accessibilityLabel(localization.string(.settings))
      }
    }
    .padding(.leading, 20)
    .padding(.trailing, 14)
    .padding(.top, 28)
    .padding(.bottom, 12)
    .background(.ultraThinMaterial)
  }

  private var bottomBar: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(statusColor)
        .frame(width: 7, height: 7)

      Text(localization.statusTitle(viewModel.status))
        .font(.caption)

      Spacer()

      Button {
        viewModel.play()
      } label: {
        Label(localization.string(.reconnect), systemImage: "arrow.clockwise")
          .font(.caption)
      }
      .buttonStyle(.borderless)
      .help(localization.string(.restartStream))
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(.ultraThinMaterial)
  }

  private var dateTimeOverlay: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      Text(formattedDateTime(context.date))
        .font(.system(.body, design: .monospaced, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
    }
    .allowsHitTesting(false)
  }

  private var statusColor: Color {
    switch viewModel.status {
    case .idle:
      .secondary
    case .connecting:
      .yellow
    case .playing:
      .green
    case .failed:
      .red
    }
  }

  private var muteActionTitle: String {
    localization.string(viewModel.isMuted ? .unmute : .mute)
  }

  private func formattedDateTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = .autoupdatingCurrent
    formatter.dateFormat = "dd-MM-yyyy HH:mm:ss"
    return formatter.string(from: date)
  }

  private func errorOverlay(message: String) -> some View {
    VStack(spacing: 14) {
      Image(systemName: "video.slash.fill")
        .font(.system(size: 34))
        .foregroundStyle(.secondary)

      Text(localization.string(.couldNotOpenStream))
        .font(.headline)

      Text(message)
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 360)

      Button(localization.string(.openSettings)) {
        isSettingsPresented = true
      }
    }
    .padding(28)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    .padding(30)
  }
}
