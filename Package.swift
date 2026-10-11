// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyDashboard",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "MyDashboard", targets: ["MyDashboard"])],
    targets: [.executableTarget(name: "MyDashboard", path: "Sources/MyDashboard")]
)
