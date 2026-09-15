import Foundation
import Testing

@testable import RTSPViewer

@MainActor
struct ActivationHookModelTests {
  @Test
  func usesDocumentedDefaultsOnFirstLaunch() {
    let defaults = makeDefaults()
    let model = ActivationHookModel(defaults: defaults)

    #expect(model.port == 23_456)
    #expect(model.pathSegment == "show")
    #expect(model.showSubstring.isEmpty)
    #expect(model.hideSubstring.isEmpty)
    #expect(model.closeTimeoutSeconds == 0)
  }

  @Test
  func validatesAndNormalizesConfiguration() throws {
    let defaults = makeDefaults()
    let model = ActivationHookModel(defaults: defaults)
    let result = model.validatedConfiguration(
      portText: " 34567 ",
      pathSegment: "/doorbell/",
      showSubstring: "active=true",
      hideSubstring: "active=false",
      closeTimeoutText: "15"
    )

    let configuration = try result.get()
    #expect(configuration.port == 34_567)
    #expect(configuration.pathSegment == "doorbell")
    #expect(configuration.showSubstring == "active=true")
    #expect(configuration.hideSubstring == "active=false")
    #expect(configuration.closeTimeoutSeconds == 15)
  }

  @Test
  func rejectsInvalidListenerValues() {
    let defaults = makeDefaults()
    let model = ActivationHookModel(defaults: defaults)

    let invalidPort = model.validatedConfiguration(
      portText: "0",
      pathSegment: "show",
      showSubstring: "",
      hideSubstring: "",
      closeTimeoutText: "0"
    )
    #expect(invalidPort == .failure(.invalidPort))

    let invalidSegment = model.validatedConfiguration(
      portText: "23456",
      pathSegment: "nested/show",
      showSubstring: "",
      hideSubstring: "",
      closeTimeoutText: "0"
    )
    #expect(invalidSegment == .failure(.invalidPathSegment))

    let invalidTimeout = model.validatedConfiguration(
      portText: "23456",
      pathSegment: "show",
      showSubstring: "",
      hideSubstring: "",
      closeTimeoutText: "-1"
    )
    #expect(invalidTimeout == .failure(.invalidCloseTimeout))
  }

  @Test
  func decodesGETParametersBeforeMatching() {
    let decoded = ActivationHTTPServer.decodedQuery(
      from: "/show/?event=door%20bell+active&source=front%2Fdoor"
    )

    #expect(decoded == "event=door bell active&source=front/door")
  }

  @Test
  func selectsShowAndHideActionsFromRequestContent() throws {
    let defaults = makeDefaults()
    let model = ActivationHookModel(defaults: defaults)
    let configuration = try model.validatedConfiguration(
      portText: "23456",
      pathSegment: "show",
      showSubstring: "state=open",
      hideSubstring: "state=closed",
      closeTimeoutText: "0"
    ).get()
    model.apply(configuration)

    #expect(
      model.action(
        for: request(method: "GET", query: "state=open", body: "", accepted: true)
      ) == .show
    )
    #expect(
      model.action(
        for: request(method: "POST", query: "", body: "state=closed", accepted: true)
      ) == .hide
    )
    #expect(
      model.action(
        for: request(method: "POST", query: "", body: "state=unknown", accepted: true)
      ) == .none
    )
    #expect(
      model.action(
        for: request(method: "GET", query: "state=open", body: "", accepted: false)
      ) == .none
    )
  }

  @Test
  func recordsRawURLAndPOSTBodyInDebugMode() {
    let defaults = makeDefaults()
    let model = ActivationHookModel(defaults: defaults)
    model.setDebugLoggingEnabled(true)

    model.handle(
      ActivationHTTPRequest(
        method: "GET",
        rawTarget: "/show/?event=door%20bell",
        decodedQuery: "event=door bell",
        body: "",
        isAcceptedEndpoint: true
      ))
    model.handle(
      ActivationHTTPRequest(
        method: "POST",
        rawTarget: "/show/",
        decodedQuery: "",
        body: "event=doorbell",
        isAcceptedEndpoint: true
      ))

    #expect(model.logEntries.count == 2)
    #expect(model.logEntries[0].method == "GET")
    #expect(model.logEntries[0].payloadKind == .url)
    #expect(model.logEntries[0].payload == "/show/?event=door%20bell")
    #expect(model.logEntries[1].method == "POST")
    #expect(model.logEntries[1].payloadKind == .body)
    #expect(model.logEntries[1].payload == "event=doorbell")
  }

  @Test
  func hidesAfterConfiguredTimeout() async throws {
    let defaults = makeDefaults()
    let model = ActivationHookModel(defaults: defaults)
    let configuration = try model.validatedConfiguration(
      portText: "23456",
      pathSegment: "show",
      showSubstring: "",
      hideSubstring: "",
      closeTimeoutText: "1"
    ).get()
    model.apply(configuration)

    var showCount = 0
    var hideCount = 0
    model.onShowRequested = { showCount += 1 }
    model.onHideRequested = { hideCount += 1 }

    model.handle(request(method: "GET", query: "", body: "", accepted: true))
    #expect(showCount == 1)
    #expect(hideCount == 0)

    try await Task.sleep(for: .milliseconds(1_200))
    #expect(hideCount == 1)
  }

  private func request(
    method: String,
    query: String,
    body: String,
    accepted: Bool
  ) -> ActivationHTTPRequest {
    ActivationHTTPRequest(
      method: method,
      rawTarget: "/show/",
      decodedQuery: query,
      body: body,
      isAcceptedEndpoint: accepted
    )
  }

  private func makeDefaults() -> UserDefaults {
    UserDefaults(suiteName: "ActivationHookModelTests.\(UUID().uuidString)")!
  }
}
