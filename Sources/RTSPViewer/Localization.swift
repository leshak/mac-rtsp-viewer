import Foundation
import Observation

enum ApplicationLanguage: String, CaseIterable, Identifiable {
  case system
  case russian
  case english

  var id: String { rawValue }
}

private enum InterfaceLanguage {
  case russian
  case english
}

enum LocalizedText {
  case openViewer
  case quitViewer
  case edit
  case undo
  case redo
  case cut
  case copy
  case paste
  case selectAll
  case cameraSettings
  case addressSavedForNextLaunch
  case pasteFromClipboard
  case pasteHelp
  case supportedAddresses
  case clear
  case cancel
  case save
  case invalidURL
  case emptyClipboard
  case language
  case languageDescription
  case systemLanguage
  case russianLanguage
  case englishLanguage
  case rtspNotConfigured
  case settings
  case mute
  case unmute
  case reconnect
  case restartStream
  case stopped
  case connecting
  case streaming
  case error
  case couldNotOpenStream
  case openSettings
  case missingURL
  case cameraUnavailable
}

@Observable
@MainActor
final class LocalizationManager {
  private(set) var preference: ApplicationLanguage

  @ObservationIgnored var onLanguageChange: (() -> Void)?

  private let defaults: UserDefaults
  private let languageKey = "appLanguage"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    preference =
      defaults.string(forKey: languageKey).flatMap(ApplicationLanguage.init(rawValue:)) ?? .system
  }

  func setPreference(_ newPreference: ApplicationLanguage) {
    guard preference != newPreference else { return }

    preference = newPreference
    defaults.set(newPreference.rawValue, forKey: languageKey)
    onLanguageChange?()
  }

  func title(for language: ApplicationLanguage) -> String {
    switch language {
    case .system:
      string(.systemLanguage)
    case .russian:
      string(.russianLanguage)
    case .english:
      string(.englishLanguage)
    }
  }

  func statusTitle(_ status: PlaybackStatus) -> String {
    switch status {
    case .idle:
      string(.stopped)
    case .connecting:
      string(.connecting)
    case .playing:
      string(.streaming)
    case .failed:
      string(.error)
    }
  }

  func playbackError(_ error: PlaybackError) -> String {
    switch error {
    case .missingURL:
      string(.missingURL)
    case .cameraUnavailable:
      string(.cameraUnavailable)
    }
  }

  func string(_ key: LocalizedText) -> String {
    switch resolvedLanguage {
    case .russian:
      russianString(key)
    case .english:
      englishString(key)
    }
  }

  private var resolvedLanguage: InterfaceLanguage {
    switch preference {
    case .russian:
      .russian
    case .english:
      .english
    case .system:
      Self.systemLanguage
    }
  }

  private static var systemLanguage: InterfaceLanguage {
    let identifier = Locale.preferredLanguages.first ?? Locale.current.identifier
    let languageCode = Locale(identifier: identifier).language.languageCode?.identifier
    return languageCode?.lowercased() == "ru" ? .russian : .english
  }

  private func russianString(_ key: LocalizedText) -> String {
    switch key {
    case .openViewer: "Открыть RTSP Viewer"
    case .quitViewer: "Завершить RTSP Viewer"
    case .edit: "Правка"
    case .undo: "Отменить"
    case .redo: "Повторить"
    case .cut: "Вырезать"
    case .copy: "Копировать"
    case .paste: "Вставить"
    case .selectAll: "Выбрать всё"
    case .cameraSettings: "Настройки камеры"
    case .addressSavedForNextLaunch: "Адрес сохраняется для следующих запусков"
    case .pasteFromClipboard: "Вставить"
    case .pasteHelp: "Вставить адрес из буфера обмена"
    case .supportedAddresses: "Поддерживаются адреса rtsp:// и rtsps://"
    case .clear: "Очистить"
    case .cancel: "Отмена"
    case .save: "Сохранить"
    case .invalidURL: "Введите полный адрес, например rtsp://192.168.1.10/stream"
    case .emptyClipboard: "В буфере обмена нет текста."
    case .language: "Язык"
    case .languageDescription: "Можно использовать язык macOS или выбрать язык приложения."
    case .systemLanguage: "Системный"
    case .russianLanguage: "Русский"
    case .englishLanguage: "Английский"
    case .rtspNotConfigured: "RTSP не настроен"
    case .settings: "Настройки"
    case .mute: "Выключить звук"
    case .unmute: "Включить звук"
    case .reconnect: "Переподключить"
    case .restartStream: "Перезапустить трансляцию"
    case .stopped: "Остановлено"
    case .connecting: "Подключение…"
    case .streaming: "Трансляция"
    case .error: "Ошибка"
    case .couldNotOpenStream: "Не удалось открыть трансляцию"
    case .openSettings: "Открыть настройки"
    case .missingURL: "Укажите RTSP URL камеры в настройках."
    case .cameraUnavailable: "Камера недоступна или отклонила подключение."
    }
  }

  private func englishString(_ key: LocalizedText) -> String {
    switch key {
    case .openViewer: "Open RTSP Viewer"
    case .quitViewer: "Quit RTSP Viewer"
    case .edit: "Edit"
    case .undo: "Undo"
    case .redo: "Redo"
    case .cut: "Cut"
    case .copy: "Copy"
    case .paste: "Paste"
    case .selectAll: "Select All"
    case .cameraSettings: "Camera Settings"
    case .addressSavedForNextLaunch: "The address is saved for future launches"
    case .pasteFromClipboard: "Paste"
    case .pasteHelp: "Paste an address from the clipboard"
    case .supportedAddresses: "rtsp:// and rtsps:// addresses are supported"
    case .clear: "Clear"
    case .cancel: "Cancel"
    case .save: "Save"
    case .invalidURL: "Enter a complete address, for example rtsp://192.168.1.10/stream"
    case .emptyClipboard: "The clipboard does not contain text."
    case .language: "Language"
    case .languageDescription: "Use the macOS language or choose an app language."
    case .systemLanguage: "System"
    case .russianLanguage: "Russian"
    case .englishLanguage: "English"
    case .rtspNotConfigured: "RTSP is not configured"
    case .settings: "Settings"
    case .mute: "Mute"
    case .unmute: "Unmute"
    case .reconnect: "Reconnect"
    case .restartStream: "Restart the stream"
    case .stopped: "Stopped"
    case .connecting: "Connecting…"
    case .streaming: "Streaming"
    case .error: "Error"
    case .couldNotOpenStream: "Unable to open the stream"
    case .openSettings: "Open Settings"
    case .missingURL: "Enter the camera RTSP URL in Settings."
    case .cameraUnavailable: "The camera is unavailable or rejected the connection."
    }
  }
}
