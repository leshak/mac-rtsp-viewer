import AppKit
import SwiftUI

struct SettingsView: View {
  @Bindable var viewModel: StreamViewModel
  @Bindable var localization: LocalizationManager
  @Environment(\.dismiss) private var dismiss

  @State private var draftURL: String
  @State private var validationError: ValidationError?

  init(viewModel: StreamViewModel, localization: LocalizationManager) {
    self.viewModel = viewModel
    self.localization = localization
    _draftURL = State(initialValue: viewModel.streamURL)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
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

        if let validationError {
          Text(validationMessage(for: validationError))
            .font(.caption)
            .foregroundStyle(.red)
        } else {
          Text(localization.string(.supportedAddresses))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

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
    }
    .padding(24)
    .frame(width: 620)
    .onChange(of: draftURL) {
      validationError = nil
    }
  }

  private func save() {
    if viewModel.saveStreamURL(draftURL) {
      dismiss()
    } else {
      validationError = .invalidURL
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
    }
  }
}

private enum ValidationError {
  case invalidURL
  case emptyClipboard
}
