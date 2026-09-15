import Foundation
import Network
import Observation

struct ActivationHookConfiguration: Equatable, Sendable {
  let port: UInt16
  let pathSegment: String
  let showSubstring: String
  let hideSubstring: String
  let closeTimeoutSeconds: Int
}

enum ActivationHookValidationError: Error, Equatable {
  case invalidPort
  case invalidPathSegment
  case invalidCloseTimeout
}

enum ActivationHookServerStatus: Equatable {
  case stopped
  case starting
  case running
  case failed(String)
}

enum ActivationHookAction: Equatable {
  case show
  case hide
  case none
}

struct ActivationHookLogEntry: Identifiable, Sendable {
  enum PayloadKind: String, Sendable {
    case url = "URL"
    case body = "BODY"
  }

  let id = UUID()
  let timestamp: Date
  let method: String
  let payloadKind: PayloadKind
  let payload: String
}

@Observable
@MainActor
final class ActivationHookModel {
  private(set) var port: UInt16
  private(set) var pathSegment: String
  private(set) var showSubstring: String
  private(set) var hideSubstring: String
  private(set) var closeTimeoutSeconds: Int
  private(set) var isDebugLoggingEnabled: Bool
  private(set) var serverStatus: ActivationHookServerStatus = .stopped
  private(set) var logEntries: [ActivationHookLogEntry] = []

  @ObservationIgnored var onShowRequested: (() -> Void)?
  @ObservationIgnored var onHideRequested: (() -> Void)?
  @ObservationIgnored var onDebugLoggingChange: ((Bool) -> Void)?

  private let defaults: UserDefaults
  @ObservationIgnored private let server = ActivationHTTPServer()
  @ObservationIgnored private var closeTask: Task<Void, Never>?

  private static let portKey = "activationHookPort"
  private static let pathSegmentKey = "activationHookPathSegment"
  private static let showSubstringKey = "activationHookShowSubstring"
  private static let hideSubstringKey = "activationHookHideSubstring"
  private static let closeTimeoutKey = "activationHookCloseTimeoutSeconds"
  private static let debugLoggingKey = "activationHookDebugLogging"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults

    let savedPort = defaults.integer(forKey: Self.portKey)
    port = savedPort > 0 ? (UInt16(exactly: savedPort) ?? 23_456) : 23_456
    let savedPathSegment = defaults.string(forKey: Self.pathSegmentKey) ?? ""
    pathSegment = savedPathSegment.isEmpty ? "show" : savedPathSegment
    showSubstring = defaults.string(forKey: Self.showSubstringKey) ?? ""
    hideSubstring = defaults.string(forKey: Self.hideSubstringKey) ?? ""
    closeTimeoutSeconds = max(0, defaults.integer(forKey: Self.closeTimeoutKey))
    isDebugLoggingEnabled = defaults.bool(forKey: Self.debugLoggingKey)
  }

  var configuration: ActivationHookConfiguration {
    ActivationHookConfiguration(
      port: port,
      pathSegment: pathSegment,
      showSubstring: showSubstring,
      hideSubstring: hideSubstring,
      closeTimeoutSeconds: closeTimeoutSeconds
    )
  }

  var percentEncodedPathSegment: String {
    pathSegment.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? pathSegment
  }

  func start() {
    restartServer()
  }

  func stop() {
    cancelPendingClose()
    server.stop()
    serverStatus = .stopped
  }

  func validatedConfiguration(
    portText: String,
    pathSegment: String,
    showSubstring: String,
    hideSubstring: String,
    closeTimeoutText: String
  ) -> Result<ActivationHookConfiguration, ActivationHookValidationError> {
    let trimmedPort = portText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let portValue = Int(trimmedPort), let port = UInt16(exactly: portValue), port > 0 else {
      return .failure(.invalidPort)
    }

    let trimmedSegment = pathSegment.trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let forbiddenCharacters = CharacterSet(charactersIn: "/?#\r\n")
    guard !trimmedSegment.isEmpty,
      trimmedSegment.rangeOfCharacter(from: forbiddenCharacters) == nil
    else {
      return .failure(.invalidPathSegment)
    }

    let trimmedTimeout = closeTimeoutText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let timeout = Int(trimmedTimeout), timeout >= 0 else {
      return .failure(.invalidCloseTimeout)
    }

    return .success(
      ActivationHookConfiguration(
        port: port,
        pathSegment: trimmedSegment,
        showSubstring: showSubstring,
        hideSubstring: hideSubstring,
        closeTimeoutSeconds: timeout
      ))
  }

  func apply(_ configuration: ActivationHookConfiguration) {
    let listenerChanged = port != configuration.port || pathSegment != configuration.pathSegment
    let shouldRestartListener: Bool
    switch serverStatus {
    case .failed:
      shouldRestartListener = true
    case .stopped, .starting, .running:
      shouldRestartListener = listenerChanged
    }

    cancelPendingClose()

    port = configuration.port
    pathSegment = configuration.pathSegment
    showSubstring = configuration.showSubstring
    hideSubstring = configuration.hideSubstring
    closeTimeoutSeconds = configuration.closeTimeoutSeconds

    defaults.set(Int(configuration.port), forKey: Self.portKey)
    defaults.set(configuration.pathSegment, forKey: Self.pathSegmentKey)
    defaults.set(configuration.showSubstring, forKey: Self.showSubstringKey)
    defaults.set(configuration.hideSubstring, forKey: Self.hideSubstringKey)
    defaults.set(configuration.closeTimeoutSeconds, forKey: Self.closeTimeoutKey)

    if shouldRestartListener {
      restartServer()
    }
  }

  func setDebugLoggingEnabled(_ isEnabled: Bool) {
    guard isDebugLoggingEnabled != isEnabled else { return }

    isDebugLoggingEnabled = isEnabled
    defaults.set(isEnabled, forKey: Self.debugLoggingKey)
    onDebugLoggingChange?(isEnabled)
  }

  func clearLog() {
    logEntries.removeAll()
  }

  func cancelPendingClose() {
    closeTask?.cancel()
    closeTask = nil
  }

  func action(for request: ActivationHTTPRequest) -> ActivationHookAction {
    guard request.isAcceptedEndpoint else { return .none }

    let input: String
    switch request.method {
    case "GET":
      input = request.decodedQuery
    case "POST":
      input = request.body
    default:
      return .none
    }

    if !hideSubstring.isEmpty, input.contains(hideSubstring) {
      return .hide
    }

    return showSubstring.isEmpty || input.contains(showSubstring) ? .show : .none
  }

  private func restartServer() {
    serverStatus = .starting
    let currentConfiguration = configuration

    server.start(
      configuration: currentConfiguration,
      requestHandler: { [weak self] request in
        Task { @MainActor [weak self] in
          self?.handle(request)
        }
      },
      stateHandler: { [weak self] status in
        Task { @MainActor [weak self] in
          self?.serverStatus = status
        }
      }
    )
  }

  func handle(_ request: ActivationHTTPRequest) {
    if isDebugLoggingEnabled {
      let payloadKind: ActivationHookLogEntry.PayloadKind = request.method == "GET" ? .url : .body
      let fullPayload = request.method == "GET" ? request.rawTarget : request.body
      let payload = limitedLogPayload(fullPayload)
      logEntries.append(
        ActivationHookLogEntry(
          timestamp: .now,
          method: request.method,
          payloadKind: payloadKind,
          payload: payload
        ))
      if logEntries.count > 500 {
        logEntries.removeFirst(logEntries.count - 500)
      }
    }

    switch action(for: request) {
    case .hide:
      cancelPendingClose()
      onHideRequested?()
    case .show:
      onShowRequested?()
      scheduleCloseIfNeeded()
    case .none:
      break
    }
  }

  private func scheduleCloseIfNeeded() {
    cancelPendingClose()
    guard closeTimeoutSeconds > 0 else { return }

    let timeout = closeTimeoutSeconds
    closeTask = Task { [weak self] in
      do {
        try await Task.sleep(for: .seconds(timeout))
      } catch {
        return
      }

      guard !Task.isCancelled else { return }
      self?.onHideRequested?()
      self?.closeTask = nil
    }
  }

  private func limitedLogPayload(_ payload: String) -> String {
    let maximumCharacters = 4_096
    guard payload.count > maximumCharacters else { return payload }
    return "\(payload.prefix(maximumCharacters))\n… [truncated]"
  }
}

struct ActivationHTTPRequest: Sendable {
  let method: String
  let rawTarget: String
  let decodedQuery: String
  let body: String
  let isAcceptedEndpoint: Bool
}

final class ActivationHTTPServer: @unchecked Sendable {
  private enum ParseResult {
    case incomplete
    case request(ActivationHTTPRequest, HTTPResponse)
    case error(HTTPResponse)
  }

  private struct HTTPResponse {
    let statusCode: Int
    let reason: String
    let body: String

    static let ok = HTTPResponse(statusCode: 200, reason: "OK", body: "OK\n")
    static let badRequest = HTTPResponse(
      statusCode: 400, reason: "Bad Request", body: "Bad Request\n")
    static let notFound = HTTPResponse(statusCode: 404, reason: "Not Found", body: "Not Found\n")
    static let methodNotAllowed = HTTPResponse(
      statusCode: 405, reason: "Method Not Allowed", body: "Method Not Allowed\n")
    static let payloadTooLarge = HTTPResponse(
      statusCode: 413, reason: "Payload Too Large", body: "Payload Too Large\n")
    static let headersTooLarge = HTTPResponse(
      statusCode: 431,
      reason: "Request Header Fields Too Large",
      body: "Request Header Fields Too Large\n"
    )
  }

  private let queue = DispatchQueue(label: "com.leshak.rtsp-viewer.activation-http-server")
  private var listener: NWListener?
  private let maximumHeaderSize = 64 * 1_024
  private let maximumBodySize = 1_024 * 1_024

  func start(
    configuration: ActivationHookConfiguration,
    requestHandler: @escaping @Sendable (ActivationHTTPRequest) -> Void,
    stateHandler: @escaping @Sendable (ActivationHookServerStatus) -> Void
  ) {
    queue.async { [weak self] in
      guard let self else { return }

      listener?.cancel()
      listener = nil

      do {
        guard let networkPort = NWEndpoint.Port(rawValue: configuration.port) else {
          stateHandler(.failed("Invalid port"))
          return
        }

        let listener = try NWListener(using: .tcp, on: networkPort)
        self.listener = listener

        listener.stateUpdateHandler = { [weak self, weak listener] state in
          guard let self, let listener, self.listener === listener else { return }

          switch state {
          case .setup, .waiting:
            stateHandler(.starting)
          case .ready:
            stateHandler(.running)
          case .failed(let error):
            stateHandler(.failed(error.localizedDescription))
          case .cancelled:
            stateHandler(.stopped)
          @unknown default:
            break
          }
        }

        listener.newConnectionHandler = { [weak self] connection in
          guard let self else { return }
          connection.start(queue: self.queue)
          self.receive(
            from: connection,
            configuration: configuration,
            requestHandler: requestHandler
          )
        }

        listener.start(queue: queue)
      } catch {
        stateHandler(.failed(error.localizedDescription))
      }
    }
  }

  func stop() {
    queue.async { [weak self] in
      self?.listener?.cancel()
      self?.listener = nil
    }
  }

  private func receive(
    from connection: NWConnection,
    buffer: Data = Data(),
    configuration: ActivationHookConfiguration,
    requestHandler: @escaping @Sendable (ActivationHTTPRequest) -> Void
  ) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1_024) {
      [weak self] data, _, isComplete, error in
      guard let self else {
        connection.cancel()
        return
      }

      var nextBuffer = buffer
      if let data {
        nextBuffer.append(data)
      }

      switch self.parse(nextBuffer, configuration: configuration) {
      case .incomplete:
        if nextBuffer.count > self.maximumHeaderSize + self.maximumBodySize {
          self.send(.payloadTooLarge, to: connection)
        } else if isComplete || error != nil {
          self.send(.badRequest, to: connection)
        } else {
          self.receive(
            from: connection,
            buffer: nextBuffer,
            configuration: configuration,
            requestHandler: requestHandler
          )
        }
      case .request(let request, let response):
        requestHandler(request)
        self.send(response, to: connection)
      case .error(let response):
        self.send(response, to: connection)
      }
    }
  }

  private func parse(_ data: Data, configuration: ActivationHookConfiguration) -> ParseResult {
    let headerSeparator = Data([13, 10, 13, 10])
    guard let headerRange = data.range(of: headerSeparator) else {
      return data.count > maximumHeaderSize ? .error(.headersTooLarge) : .incomplete
    }
    guard headerRange.lowerBound <= maximumHeaderSize else {
      return .error(.headersTooLarge)
    }

    let headerData = data[..<headerRange.lowerBound]
    guard let headerText = String(data: headerData, encoding: .utf8) else {
      return .error(.badRequest)
    }

    let lines = headerText.components(separatedBy: "\r\n")
    guard let requestLine = lines.first else {
      return .error(.badRequest)
    }
    let requestParts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
    guard requestParts.count == 3 else {
      return .error(.badRequest)
    }

    let method = requestParts[0].uppercased()
    let rawTarget = String(requestParts[1])
    var contentLength = 0

    for line in lines.dropFirst() {
      guard let separator = line.firstIndex(of: ":") else { continue }
      let name = line[..<separator].trimmingCharacters(in: .whitespaces).lowercased()
      guard name == "content-length" else { continue }
      let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
      guard let parsedLength = Int(value), parsedLength >= 0 else {
        return .error(.badRequest)
      }
      contentLength = parsedLength
    }

    guard contentLength <= maximumBodySize else {
      return .error(.payloadTooLarge)
    }

    let bodyStart = headerRange.upperBound
    guard data.count >= bodyStart + contentLength else {
      return .incomplete
    }

    let bodyData = data[bodyStart..<(bodyStart + contentLength)]
    let body = String(decoding: bodyData, as: UTF8.self)
    let path = Self.decodedPath(from: rawTarget)
    let expectedPath = "/\(configuration.pathSegment)"
    let isExpectedPath = path == expectedPath || path == "\(expectedPath)/"
    let isSupportedMethod = method == "GET" || method == "POST"
    let response: HTTPResponse

    if !isSupportedMethod {
      response = .methodNotAllowed
    } else if !isExpectedPath {
      response = .notFound
    } else {
      response = .ok
    }

    return .request(
      ActivationHTTPRequest(
        method: method,
        rawTarget: rawTarget,
        decodedQuery: Self.decodedQuery(from: rawTarget),
        body: body,
        isAcceptedEndpoint: isSupportedMethod && isExpectedPath
      ),
      response
    )
  }

  private static func decodedPath(from rawTarget: String) -> String {
    let path =
      rawTarget.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first
      .map(String.init) ?? rawTarget
    return path.removingPercentEncoding ?? path
  }

  static func decodedQuery(from rawTarget: String) -> String {
    guard let questionMark = rawTarget.firstIndex(of: "?") else { return "" }

    let queryStart = rawTarget.index(after: questionMark)
    let queryWithFragment = String(rawTarget[queryStart...])
    let query =
      queryWithFragment.split(
        separator: "#", maxSplits: 1, omittingEmptySubsequences: false
      ).first.map(String.init) ?? queryWithFragment

    return query.split(separator: "&", omittingEmptySubsequences: false).map { field in
      let parts = field.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
      let name = decodeFormComponent(String(parts[0]))
      guard parts.count == 2 else { return name }
      return "\(name)=\(decodeFormComponent(String(parts[1])))"
    }.joined(separator: "&")
  }

  private static func decodeFormComponent(_ value: String) -> String {
    let plusDecoded = value.replacingOccurrences(of: "+", with: " ")
    return plusDecoded.removingPercentEncoding ?? plusDecoded
  }

  private func send(_ response: HTTPResponse, to connection: NWConnection) {
    let bodyData = Data(response.body.utf8)
    let header = """
      HTTP/1.1 \(response.statusCode) \(response.reason)\r
      Content-Type: text/plain; charset=utf-8\r
      Content-Length: \(bodyData.count)\r
      Connection: close\r
      \r

      """
    var responseData = Data(header.utf8)
    responseData.append(bodyData)

    connection.send(
      content: responseData,
      completion: .contentProcessed { _ in
        connection.cancel()
      })
  }
}
