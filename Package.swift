// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HibernateNow",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "HibernateNow", targets: ["HibernateNow"])
    ],
    targets: [
        .executableTarget(name: "HibernateNow", path: "Sources/HibernateNow")
    ]
)
