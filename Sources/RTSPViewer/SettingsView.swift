import AppKit
import SwiftUI

struct SettingsView: View {
  @Bindable var viewModel: StreamViewModel
  @Environment(\.dismiss) private var dismiss

  @State private var draftURL: String
  @State private var validationMessage: String?

  init(viewModel: StreamViewModel) {
    self.viewModel = viewModel
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
          Text("Настройки камеры")
            .font(.title3.weight(.semibold))
          Text("Адрес сохраняется для следующих запусков")
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
            Label("Вставить", systemImage: "doc.on.clipboard")
          }
          .help("Вставить адрес из буфера обмена")
        }

        if let validationMessage {
          Text(validationMessage)
            .font(.caption)
            .foregroundStyle(.red)
        } else {
          Text("Поддерживаются адреса rtsp:// и rtsps://")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      HStack {
        Button("Очистить", role: .destructive) {
          viewModel.clearStreamURL()
          dismiss()
        }
        .disabled(viewModel.streamURL.isEmpty)

        Spacer()

        Button("Отмена") {
          dismiss()
        }
        .keyboardShortcut(.cancelAction)

        Button("Сохранить") {
          save()
        }
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(24)
    .frame(width: 600)
    .onChange(of: draftURL) {
      validationMessage = nil
    }
  }

  private func save() {
    if viewModel.saveStreamURL(draftURL) {
      dismiss()
    } else {
      validationMessage = "Введите полный адрес, например rtsp://192.168.1.10/stream"
    }
  }

  private func pasteFromClipboard() {
    guard let clipboardText = NSPasteboard.general.string(forType: .string) else {
      validationMessage = "В буфере обмена нет текста."
      return
    }

    draftURL = clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
