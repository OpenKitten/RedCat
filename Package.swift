// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "RedCat",
    targets: [
        Target(name: "RedCat"),
        Target(name: "Example", dependencies: ["RedCat"])
    ],
    dependencies: [
        // Provides sockets
        .Package(url: "https://github.com/vapor/socks.git", majorVersion: 1),
        
        // SSL
        .Package(url: "https://github.com/vapor/tls.git", majorVersion: 1),
    ]
)
