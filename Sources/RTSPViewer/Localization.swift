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
  case videoOverlay
  case showDateTime
  case dateTimeDescription
  case activationHook
  case activationHookDescription
  case httpPort
  case urlPathSegment
  case showWhenContains
  case showSubstringPlaceholder
  case showWhenContainsDescription
  case hideWhenContains
  case hideSubstringPlaceholder
  case hideWhenContainsDescription
  case closeAfterTimeout
  case closeAfterTimeoutDescription
  case seconds
  case debugMode
  case debugModeDescription
  case incomingRequestLog
  case clearLog
  case waitingForRequests
  case waitingForRequestsDescription
  case hookServerRunning
  case hookServerStarting
  case hookServerStopped
  case hookServerFailed
  case invalidHookPort
  case invalidHookPathSegment
  case invalidCloseTimeout
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
    case .videoOverlay: "Поверх видео"
    case .showDateTime: "Показывать дату и время"
    case .dateTimeDescription: "Дата и время отображаются в формате ДД-ММ-ГГГГ ЧЧ:мм:сс."
    case .activationHook: "HTTP hook окна"
    case .activationHookDescription:
      "Встроенный сервер принимает GET и POST и управляет окном по содержимому запроса."
    case .httpPort: "HTTP-порт"
    case .urlPathSegment: "Сегмент URL"
    case .showWhenContains: "Показать окно, если запрос содержит"
    case .showSubstringPlaceholder: "Например: motion=detected"
    case .showWhenContainsDescription:
      "Для GET проверяются декодированные параметры, для POST — BODY как строка. Пустое поле принимает любой запрос."
    case .hideWhenContains: "Скрыть окно, если запрос содержит"
    case .hideSubstringPlaceholder: "Например: motion=stopped"
    case .hideWhenContainsDescription:
      "Пустое поле отключает скрытие по содержимому. Правило скрытия имеет приоритет."
    case .closeAfterTimeout: "Скрыть через"
    case .closeAfterTimeoutDescription:
      "Таймаут отсчитывается заново после каждого показа. 0 отключает его."
    case .seconds: "сек."
    case .debugMode: "Режим отладки"
    case .debugModeDescription:
      "При включении открывается отдельное окно с URL и BODY входящих запросов."
    case .incomingRequestLog: "Лог входящих HTTP-запросов"
    case .clearLog: "Очистить лог"
    case .waitingForRequests: "Ожидание запросов"
    case .waitingForRequestsDescription: "Здесь появятся метод запроса и полученный URL или BODY."
    case .hookServerRunning: "HTTP-сервер запущен"
    case .hookServerStarting: "HTTP-сервер запускается…"
    case .hookServerStopped: "HTTP-сервер остановлен"
    case .hookServerFailed: "Не удалось запустить HTTP-сервер"
    case .invalidHookPort: "Порт должен быть целым числом от 1 до 65535."
    case .invalidHookPathSegment: "Введите один непустой сегмент URL без /, ?, или #."
    case .invalidCloseTimeout: "Таймаут должен быть целым неотрицательным числом секунд."
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
    case .videoOverlay: "Video Overlay"
    case .showDateTime: "Show date and time"
    case .dateTimeDescription: "The date and time are displayed as DD-MM-YYYY HH:mm:ss."
    case .activationHook: "Window HTTP Hook"
    case .activationHookDescription:
      "The built-in server accepts GET and POST requests and controls the window from their content."
    case .httpPort: "HTTP Port"
    case .urlPathSegment: "URL Path Segment"
    case .showWhenContains: "Show the window when the request contains"
    case .showSubstringPlaceholder: "For example: motion=detected"
    case .showWhenContainsDescription:
      "Decoded parameters are checked for GET; the BODY is checked as a string for POST. An empty field accepts every request."
    case .hideWhenContains: "Hide the window when the request contains"
    case .hideSubstringPlaceholder: "For example: motion=stopped"
    case .hideWhenContainsDescription:
      "An empty field disables content-based hiding. The hide rule takes priority."
    case .closeAfterTimeout: "Hide after"
    case .closeAfterTimeoutDescription:
      "The timer restarts after each show request. Set it to 0 to disable it."
    case .seconds: "sec."
    case .debugMode: "Debug Mode"
    case .debugModeDescription:
      "Enabling it opens a separate window with incoming request URLs and bodies."
    case .incomingRequestLog: "Incoming HTTP Request Log"
    case .clearLog: "Clear Log"
    case .waitingForRequests: "Waiting for Requests"
    case .waitingForRequestsDescription:
      "The request method and received URL or BODY will appear here."
    case .hookServerRunning: "HTTP server is running"
    case .hookServerStarting: "HTTP server is starting…"
    case .hookServerStopped: "HTTP server is stopped"
    case .hookServerFailed: "Unable to start the HTTP server"
    case .invalidHookPort: "The port must be an integer from 1 through 65535."
    case .invalidHookPathSegment: "Enter one non-empty URL segment without /, ?, or #."
    case .invalidCloseTimeout: "The timeout must be a non-negative whole number of seconds."
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
