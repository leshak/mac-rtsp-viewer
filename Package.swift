// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "RTSPViewer",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .executable(name: "RTSPViewer", targets: ["RTSPViewer"])
  ],
  dependencies: [
    .package(
      url: "https://github.com/dooop/swift-vlc",
      exact: "0.3.1"
    )
  ],
  targets: [
    .executableTarget(
      name: "RTSPViewer",
      dependencies: [
        .product(name: "VLC", package: "swift-vlc")
      ],
      path: "Sources/RTSPViewer",
      swiftSettings: [
        .swiftLanguageMode(.v6)
      ]
    ),
    .testTarget(
      name: "RTSPViewerTests",
      dependencies: ["RTSPViewer"],
      path: "Tests/RTSPViewerTests"
    ),
  ]
)
