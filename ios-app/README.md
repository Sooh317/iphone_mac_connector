# iPhone-Mac Connector iOS App

A SwiftUI-based iOS application that connects to a Mac server via WebSocket to execute terminal commands remotely.

## Project Information

- **Bundle ID**: `com.iphone-mac-connector.app`
- **Deployment Target**: iOS 16.0+
- **Language**: Swift
- **UI Framework**: SwiftUI
- **Architecture**: MVVM with Service Layer

## Project Structure

```
IphoneMacConnector/
├── IphoneMacConnector/
│   ├── IphoneMacConnectorApp.swift     # Main app entry point
│   ├── Info.plist                       # App configuration
│   │
│   ├── Models/
│   │   ├── Message.swift               # WebSocket message models (input, output, error, heartbeat)
│   │   └── ConnectionConfig.swift      # Connection settings with validation
│   │
│   ├── Services/
│   │   ├── KeychainService.swift       # Secure token storage using iOS Keychain
│   │   ├── WebSocketService.swift      # WebSocket connection management
│   │   └── TerminalOutputManager.swift # Terminal output buffering and ANSI handling
│   │
│   ├── Views/
│   │   ├── ContentView.swift           # Main view with connection state logic
│   │   ├── ConnectionSettingsView.swift # Server configuration UI
│   │   ├── TerminalView.swift          # Terminal output display
│   │   └── CommandInputView.swift      # Command input with history
│   │
│   └── Assets.xcassets/
│       ├── AppIcon.appiconset/
│       └── Contents.json
│
└── IphoneMacConnector.xcodeproj/
    └── project.pbxproj
```

## Features

### Phase 9-10: Project Structure & Data Models
- ✅ Complete SwiftUI project structure
- ✅ Message models for WebSocket communication
- ✅ Connection configuration with validation
- ✅ Codable support for JSON serialization

### Phase 11: Keychain Service
- ✅ Secure token storage in iOS Keychain
- ✅ CRUD operations for authentication token
- ✅ Error handling for Keychain operations

### Phase 12: WebSocket Service
- ✅ URLSessionWebSocketTask implementation
- ✅ Bearer token authorization
- ✅ Connection state management (@Published)
- ✅ Auto-reconnect with exponential backoff
- ✅ Heartbeat every 30 seconds
- ✅ Message send/receive with callbacks
- ✅ Comprehensive error handling

### Phase 13: Terminal Output Manager
- ✅ Thread-safe output buffer
- ✅ 10,000 line limit with automatic cleanup
- ✅ ANSI escape sequence stripping
- ✅ SwiftUI reactive updates (@Published)

### Phase 14-16: Views
- ✅ **ConnectionSettingsView**: Server configuration with validation
- ✅ **TerminalView**: Monospace terminal output with auto-scroll
- ✅ **CommandInputView**: Input field with command history
- ✅ **ContentView**: Main view orchestrating connection flow

## Key Components

### WebSocketService
Manages WebSocket connections with the following features:
- Connection states: disconnected, connecting, connected, error
- Automatic reconnection (up to 5 attempts)
- Heartbeat mechanism to keep connection alive
- Message type handling: input, output, resize, error, heartbeat

### KeychainService
Provides secure storage for the authentication token:
- Uses `kSecClassGenericPassword` for token storage
- Singleton pattern for app-wide access
- Atomic CRUD operations

### TerminalOutputManager
Handles terminal output efficiently:
- Thread-safe buffer management with NSLock
- ANSI escape sequence removal for clean display
- Automatic line limit enforcement
- Real-time UI updates via Combine

## Configuration

### Connection Settings
- **Host**: IP address or hostname of Mac server
- **Port**: WebSocket port (default: 8765)
- **Token**: Authentication token (stored in Keychain)

### Network Security
The app allows arbitrary loads in `Info.plist` for local network connections:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

## Usage

1. Open the project in Xcode
2. Build and run on iOS device or simulator
3. Enter server connection details:
   - Host (e.g., "192.168.1.100")
   - Port (e.g., 8765)
   - Access token
4. Tap "Connect" to establish WebSocket connection
5. Execute commands via the command input field
6. View output in the terminal display

## Building

### Requirements
- Xcode 15.0 or later
- iOS 16.0+ deployment target
- Swift 5.0+

### Build Steps
```bash
# Open project in Xcode
open IphoneMacConnector.xcodeproj

# Or build from command line
xcodebuild -project IphoneMacConnector.xcodeproj \
           -scheme IphoneMacConnector \
           -configuration Debug \
           -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Code Quality

### Swift Best Practices
- ✅ Proper use of `@StateObject` and `@ObservedObject`
- ✅ Thread-safe service implementations
- ✅ Comprehensive error handling
- ✅ Memory management with `weak self` in closures
- ✅ Codable conformance for data models
- ✅ SwiftUI reactive patterns with Combine

### Architecture
- **MVVM**: Views observe ViewModels (Services)
- **Service Layer**: Business logic separated from UI
- **Dependency Injection**: Services passed to views
- **Single Responsibility**: Each file has a clear purpose

## Security Considerations

1. **Token Storage**: Authentication tokens stored in iOS Keychain
2. **Network Security**: App allows local network access for development
3. **Secure Input**: Uses `SecureField` for token entry
4. **No Hardcoded Secrets**: All credentials user-provided

## Future Enhancements

- [ ] SSH key-based authentication
- [ ] Multiple server profiles
- [ ] Advanced ANSI color support
- [ ] File upload/download
- [ ] Session persistence
- [ ] Dark/light theme toggle
- [ ] iPad split-view optimization
- [ ] Landscape keyboard optimization

## License

Part of the iPhone-Mac Connector project.
