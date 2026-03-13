# GlobalTimeKit

Lightweight NTP client for Swift. Get accurate server time on Apple platforms, immune to manual clock changes.

In many applications it's critical to have a reliable timestamp — for token generation, certificate validation, or time-sensitive logic. `Date()` returns the device's system clock, which users can change at any time. GlobalTimeKit solves this by querying NTP servers and caching the offset, so you always get the real time.

## Features

- **Zero dependencies** — only Foundation + Network.framework
- **async/await** as the primary API, with completion handler wrappers
- **Thread-safe** — fully `Sendable`, safe to use from any thread or actor
- **Monotonic clock** — cached offset is immune to manual clock changes
- **Multi-sample sync** — collects multiple NTP samples, picks the most accurate one
- **NTP v4** — implements RFC 5905 client mode
- **Swift 5 & 6** — strict concurrency safe

## Requirements

- **iOS** 16.0+
- **macOS** 13.0+
- **tvOS** 16.0+
- **watchOS** 9.0+
- **visionOS** 1.0+

## Installation

### Swift Package Manager

Add GlobalTimeKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/dimayurkovski/GlobalTimeKit.git", from: "1.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies** and paste the repository URL.

### CocoaPods

Add GlobalTimeKit to your `Podfile`:

```ruby
pod 'GlobalTimeKit'
```

## Usage

### Quick Start

```swift
import GlobalTimeKit

let client = GlobalTimeClient()

// Sync with NTP server (collects 4 samples by default)
try await client.sync()

// Get corrected time instantly — no await, no network
let now = client.now
```

### One-Shot Query

If you just need the server time once without caching:

```swift
let serverTime = try await GlobalTimeClient().fetchTime()
```

### Custom Server

```swift
let config = GlobalTimeConfig(
    server: "time.google.com",
    timeout: .seconds(10),
    samples: 6
)
let client = GlobalTimeClient(config: config)
try await client.sync()
```

### Check Sync Status

```swift
if client.isSynced {
    print("Offset: \(client.offset) seconds")
    print("Last sync: \(client.lastSyncDate!)")
    print("Server time: \(client.now)")
} else {
    print("Not synced, using system time")
}
```

### Completion Handler API

For projects that don't use async/await:

```swift
client.sync { result in
    switch result {
    case .success:
        print("Synced! Offset: \(client.offset)")
    case .failure(let error):
        print("Error: \(error)")
    }
}

client.fetchTime { result in
    switch result {
    case .success(let date):
        print("Server time: \(date)")
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

### Error Handling

```swift
do {
    try await client.sync()
} catch let error as GlobalTimeError {
    switch error {
    case .timeout:
        print("Request timed out")
    case .invalidResponse:
        print("Invalid NTP response")
    case .dnsResolutionFailed:
        print("Could not resolve server hostname")
    case .networkUnavailable:
        print("No network connection")
    case .serverUnreachable:
        print("NTP server is unreachable")
    }
}
```

## How It Works

GlobalTimeKit sends a UDP packet to an NTP server and calculates the clock offset using the standard NTP formula:

```
offset = ((T2 - T1) + (T3 - T4)) / 2
```

Where T1–T4 are the four timestamps from the NTP exchange. The offset is cached locally, and `client.now` returns `Date() + offset` — no network call needed after sync.

Multiple samples are collected and the one with the lowest round-trip delay is selected for maximum accuracy.

## API Reference

### GlobalTimeClient

| Property / Method | Description |
|---|---|
| `init(config:)` | Create a client with optional configuration |
| `sync()` | Sync with NTP server, cache the offset |
| `fetchTime()` | One-shot query, returns server time without caching |
| `now` | Corrected time using cached offset (falls back to `Date()`) |
| `isSynced` | Whether the client has synced at least once |
| `offset` | Cached NTP offset in seconds |
| `lastSyncDate` | Date of last successful sync |

### GlobalTimeConfig

| Parameter | Default | Description |
|---|---|---|
| `server` | `"time.apple.com"` | NTP server hostname |
| `timeout` | `.seconds(5)` | Timeout for a single NTP request |
| `samples` | `4` | Number of NTP samples to collect |

### GlobalTimeError

| Case | Description |
|---|---|
| `.timeout` | Request timed out |
| `.invalidResponse` | Server returned an invalid NTP packet |
| `.dnsResolutionFailed` | Could not resolve server hostname |
| `.networkUnavailable` | No network connection |
| `.serverUnreachable` | NTP server is unreachable |

## License

GlobalTimeKit is available under the MIT license. See the [LICENSE](LICENSE) file for more information.
