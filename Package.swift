// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pomodoro",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "PomodoroCore",
            path: "Sources/PomodoroCore"
        ),
        .executableTarget(
            name: "Pomodoro",
            dependencies: ["PomodoroCore"],
            path: "Sources/Pomodoro"
        ),
        .testTarget(
            name: "PomodoroCoreTests",
            dependencies: ["PomodoroCore"],
            path: "Tests/PomodoroCoreTests"
        ),
    ]
)
