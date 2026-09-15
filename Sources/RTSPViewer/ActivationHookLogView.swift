import SwiftUI

struct ActivationHookLogView: View {
  @Bindable var model: ActivationHookModel
  @Bindable var localization: LocalizationManager

  private let timestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    return formatter
  }()

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(localization.string(.incomingRequestLog))
            .font(.headline)
          Text(endpoint)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
        }

        Spacer()

        Button(localization.string(.clearLog)) {
          model.clearLog()
        }
        .disabled(model.logEntries.isEmpty)
      }
      .padding(14)

      Divider()

      if model.logEntries.isEmpty {
        ContentUnavailableView(
          localization.string(.waitingForRequests),
          systemImage: "network",
          description: Text(localization.string(.waitingForRequestsDescription))
        )
      } else {
        List(model.logEntries) { entry in
          HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(timestampFormatter.string(from: entry.timestamp))
              .foregroundStyle(.secondary)
            Text(entry.method)
              .fontWeight(.semibold)
              .frame(width: 46, alignment: .leading)
            Text(entry.payloadKind.rawValue)
              .foregroundStyle(.secondary)
              .frame(width: 42, alignment: .leading)
            Text(entry.payload.isEmpty ? "—" : entry.payload)
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .font(.system(.caption, design: .monospaced))
        }
      }
    }
    .frame(minWidth: 520, minHeight: 260)
  }

  private var endpoint: String {
    "http://<IP>:\(model.port)/\(model.percentEncodedPathSegment)/"
  }
}
