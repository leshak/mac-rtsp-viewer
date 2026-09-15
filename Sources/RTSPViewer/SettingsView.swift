import AppKit
import SwiftUI

struct SettingsView: View {
  @Bindable var viewModel: StreamViewModel
  @Bindable var activationHook: ActivationHookModel
  @Bindable var localization: LocalizationManager
  @Environment(\.dismiss) private var dismiss

  @State private var draftURL: String
  @State private var draftHookPort: String
  @State private var draftHookPathSegment: String
  @State private var draftShowSubstring: String
  @State private var draftHideSubstring: String
  @State private var draftCloseTimeout: String
  @State private var validationError: ValidationError?

  init(
    viewModel: StreamViewModel,
    activationHook: ActivationHookModel,
    localization: LocalizationManager
  ) {
    self.viewModel = viewModel
    self.activationHook = activationHook
    self.localization = localization
    _draftURL = State(initialValue: viewModel.streamURL)
    _draftHookPort = State(initialValue: String(activationHook.port))
    _draftHookPathSegment = State(initialValue: activationHook.pathSegment)
    _draftShowSubstring = State(initialValue: activationHook.showSubstring)
    _draftHideSubstring = State(initialValue: activationHook.hideSubstring)
    _draftCloseTimeout = State(initialValue: String(activationHook.closeTimeoutSeconds))
  }

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          HStack(spacing: 12) {
            Image(systemName: "camera.fill")
              .font(.system(size: 25))
              .foregroundStyle(.tint)
              .frame(width: 38, height: 38)
              .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
              Text(localization.string(.cameraSettings))
                .font(.title3.weight(.semibold))
              Text(localization.string(.addressSavedForNextLaunch))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }

          cameraURLSection
          videoOverlaySection

          Divider()

          activationHookSection

          Divider()

          languageSection
        }
        .padding(24)
      }

      Divider()

      HStack {
        Button(localization.string(.clear), role: .destructive) {
          viewModel.clearStreamURL()
          dismiss()
        }
        .disabled(viewModel.streamURL.isEmpty)

        Spacer()

        Button(localization.string(.cancel)) {
          dismiss()
        }
        .keyboardShortcut(.cancelAction)

        Button(localization.string(.save)) {
          save()
        }
        .keyboardShortcut(.defaultAction)
      }
      .padding(16)
    }
    .frame(width: 680, height: 720)
    .onChange(of: draftURL) { validationError = nil }
    .onChange(of: draftHookPort) { validationError = nil }
    .onChange(of: draftHookPathSegment) { validationError = nil }
    .onChange(of: draftCloseTimeout) { validationError = nil }
  }

  private var cameraURLSection: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text("RTSP URL")
        .font(.subheadline.weight(.medium))

      HStack(spacing: 8) {
        TextField("rtsp://camera.local:8554/stream", text: $draftURL)
          .textFieldStyle(.roundedBorder)
          .fontDesign(.monospaced)
          .onSubmit(save)

        Button {
          pasteFromClipboard()
        } label: {
          Label(localization.string(.pasteFromClipboard), systemImage: "doc.on.clipboard")
        }
        .help(localization.string(.pasteHelp))
      }

      if validationError == .invalidURL || validationError == .emptyClipboard {
        Text(validationMessage(for: validationError!))
          .font(.caption)
          .foregroundStyle(.red)
      } else {
        Text(localization.string(.supportedAddresses))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var videoOverlaySection: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(localization.string(.videoOverlay))
        .font(.subheadline.weight(.medium))

      Toggle(
        localization.string(.showDateTime),
        isOn: Binding(
          get: { viewModel.isDateTimeVisible },
          set: { viewModel.setDateTimeVisible($0) }
        )
      )

      Text(localization.string(.dateTimeDescription))
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var activationHookSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "network")
          .foregroundStyle(.tint)
          .frame(width: 24)

        VStack(alignment: .leading, spacing: 2) {
          Text(localization.string(.activationHook))
            .font(.headline)
          Text(localization.string(.activationHookDescription))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 5) {
          Text(localization.string(.httpPort))
            .font(.subheadline.weight(.medium))
          TextField("23456", text: $draftHookPort)
            .textFieldStyle(.roundedBorder)
            .frame(width: 120)
        }

        VStack(alignment: .leading, spacing: 5) {
          Text(localization.string(.urlPathSegment))
            .font(.subheadline.weight(.medium))
          TextField("show", text: $draftHookPathSegment)
            .textFieldStyle(.roundedBorder)
            .fontDesign(.monospaced)
        }
      }

      Text(endpointPreview)
        .font(.caption.monospaced())
        .foregroundStyle(.secondary)
        .textSelection(.enabled)

      VStack(alignment: .leading, spacing: 5) {
        Text(localization.string(.showWhenContains))
          .font(.subheadline.weight(.medium))
        TextField(localization.string(.showSubstringPlaceholder), text: $draftShowSubstring)
          .textFieldStyle(.roundedBorder)
        Text(localization.string(.showWhenContainsDescription))
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      VStack(alignment: .leading, spacing: 5) {
        Text(localization.string(.hideWhenContains))
          .font(.subheadline.weight(.medium))
        TextField(localization.string(.hideSubstringPlaceholder), text: $draftHideSubstring)
          .textFieldStyle(.roundedBorder)
        Text(localization.string(.hideWhenContainsDescription))
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(localization.string(.closeAfterTimeout))
          .font(.subheadline.weight(.medium))
        TextField("0", text: $draftCloseTimeout)
          .textFieldStyle(.roundedBorder)
          .frame(width: 80)
        Text(localization.string(.seconds))
          .foregroundStyle(.secondary)
      }

      Text(localization.string(.closeAfterTimeoutDescription))
        .font(.caption)
        .foregroundStyle(.secondary)

      Toggle(
        localization.string(.debugMode),
        isOn: Binding(
          get: { activationHook.isDebugLoggingEnabled },
          set: { activationHook.setDebugLoggingEnabled($0) }
        )
      )

      Text(localization.string(.debugModeDescription))
        .font(.caption)
        .foregroundStyle(.secondary)

      HStack(spacing: 7) {
        Circle()
          .fill(hookStatusColor)
          .frame(width: 7, height: 7)
        Text(hookStatusText)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if let validationError, validationError.isHookError {
        Text(validationMessage(for: validationError))
          .font(.caption)
          .foregroundStyle(.red)
      }
    }
  }

  private var languageSection: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(localization.string(.language))
        .font(.subheadline.weight(.medium))

      Picker(
        localization.string(.language),
        selection: Binding(
          get: { localization.preference },
          set: { localization.setPreference($0) }
        )
      ) {
        ForEach(ApplicationLanguage.allCases) { language in
          Text(localization.title(for: language)).tag(language)
        }
      }
      .labelsHidden()
      .pickerStyle(.segmented)

      Text(localization.string(.languageDescription))
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private func save() {
    let trimmedURL = draftURL.trimmingCharacters(in: .whitespacesAndNewlines)
    guard viewModel.validatedURL(from: trimmedURL) != nil else {
      validationError = .invalidURL
      return
    }

    switch activationHook.validatedConfiguration(
      portText: draftHookPort,
      pathSegment: draftHookPathSegment,
      showSubstring: draftShowSubstring,
      hideSubstring: draftHideSubstring,
      closeTimeoutText: draftCloseTimeout
    ) {
    case .success(let configuration):
      activationHook.apply(configuration)
      _ = viewModel.saveStreamURL(trimmedURL)
      dismiss()
    case .failure(let error):
      switch error {
      case .invalidPort:
        validationError = .invalidHookPort
      case .invalidPathSegment:
        validationError = .invalidHookPathSegment
      case .invalidCloseTimeout:
        validationError = .invalidCloseTimeout
      }
    }
  }

  private func pasteFromClipboard() {
    guard let clipboardText = NSPasteboard.general.string(forType: .string) else {
      validationError = .emptyClipboard
      return
    }

    draftURL = clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func validationMessage(for error: ValidationError) -> String {
    switch error {
    case .invalidURL:
      localization.string(.invalidURL)
    case .emptyClipboard:
      localization.string(.emptyClipboard)
    case .invalidHookPort:
      localization.string(.invalidHookPort)
    case .invalidHookPathSegment:
      localization.string(.invalidHookPathSegment)
    case .invalidCloseTimeout:
      localization.string(.invalidCloseTimeout)
    }
  }

  private var endpointPreview: String {
    let port = draftHookPort.trimmingCharacters(in: .whitespacesAndNewlines)
    let segment = draftHookPathSegment.trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let encodedSegment =
      segment.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? segment
    return "http://<IP>:\(port)/\(encodedSegment)/"
  }

  private var hookStatusColor: Color {
    switch activationHook.serverStatus {
    case .running:
      .green
    case .starting:
      .yellow
    case .stopped:
      .secondary
    case .failed:
      .red
    }
  }

  private var hookStatusText: String {
    switch activationHook.serverStatus {
    case .running:
      localization.string(.hookServerRunning)
    case .starting:
      localization.string(.hookServerStarting)
    case .stopped:
      localization.string(.hookServerStopped)
    case .failed(let message):
      "\(localization.string(.hookServerFailed)): \(message)"
    }
  }
}

private enum ValidationError: Equatable {
  case invalidURL
  case emptyClipboard
  case invalidHookPort
  case invalidHookPathSegment
  case invalidCloseTimeout

  var isHookError: Bool {
    switch self {
    case .invalidURL, .emptyClipboard:
      false
    case .invalidHookPort, .invalidHookPathSegment, .invalidCloseTimeout:
      true
    }
  }
}
