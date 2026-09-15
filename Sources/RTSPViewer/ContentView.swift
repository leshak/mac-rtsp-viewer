import SwiftUI

struct ContentView: View {
  @Bindable var viewModel: StreamViewModel
  @State private var isSettingsPresented = false

  var body: some View {
    ZStack {
      Color.black

      VLCVideoView(player: viewModel.player)
        .frame(maxWidth: .infinity, maxHeight: .infinity)

      if let errorMessage = viewModel.displayedErrorMessage {
        errorOverlay(message: errorMessage)
      }

      VStack(spacing: 0) {
        topBar
        Spacer()
        bottomBar
      }
    }
    .ignoresSafeArea()
    .sheet(isPresented: $isSettingsPresented) {
      SettingsView(viewModel: viewModel)
    }
  }

  private var topBar: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text("RTSP Viewer")
          .font(.headline)
        Text(viewModel.streamHost)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Button {
        isSettingsPresented = true
      } label: {
        Image(systemName: "gearshape.fill")
          .font(.system(size: 14, weight: .semibold))
          .frame(width: 30, height: 30)
      }
      .buttonStyle(.borderless)
      .help("Настройки")
      .accessibilityLabel("Настройки")
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

      Text(viewModel.status.title)
        .font(.caption)

      Spacer()

      Button {
        viewModel.play()
      } label: {
        Label("Переподключить", systemImage: "arrow.clockwise")
          .font(.caption)
      }
      .buttonStyle(.borderless)
      .help("Перезапустить трансляцию")
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(.ultraThinMaterial)
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

  private func errorOverlay(message: String) -> some View {
    VStack(spacing: 14) {
      Image(systemName: "video.slash.fill")
        .font(.system(size: 34))
        .foregroundStyle(.secondary)

      Text("Не удалось открыть трансляцию")
        .font(.headline)

      Text(message)
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 360)

      Button("Открыть настройки") {
        isSettingsPresented = true
      }
    }
    .padding(28)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    .padding(30)
  }
}
