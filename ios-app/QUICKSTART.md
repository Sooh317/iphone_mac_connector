# Quick Start Guide - iPhone-Mac Connector iOS App

## 1. Open the Project

```bash
cd /Users/sooh/Devs/iphone_mac_connector/ios-app/IphoneMacConnector
open IphoneMacConnector.xcodeproj
```

Or double-click `IphoneMacConnector.xcodeproj` in Finder.

## 2. Configure Project Settings

### In Xcode:

1. **Select the project** in the navigator (blue icon)
2. **Select the target** "IphoneMacConnector"
3. **Go to "Signing & Capabilities" tab**
4. **Select your Team** from the dropdown
5. *(Optional)* Change Bundle Identifier if needed

### No Additional Dependencies
This project uses only native iOS frameworks:
- SwiftUI
- Foundation
- Security (Keychain)
- Combine

No CocoaPods, SPM, or Carthage needed!

## 3. Build and Run

### Option A: iOS Simulator
1. **Select a simulator** from the device dropdown (e.g., "iPhone 15")
2. **Click the Play button** (⌘R) or Product → Run
3. Wait for build to complete

### Option B: Physical iOS Device
1. **Connect your iPhone** via USB
2. **Select your device** from the device dropdown
3. **Click the Play button** (⌘R)
4. If prompted, **trust the developer certificate** on your iPhone:
   - Settings → General → VPN & Device Management
   - Tap your Apple ID
   - Tap "Trust"

## 4. First Launch Configuration

When the app launches:

1. You'll see the **Connection Settings** screen
2. Fill in the server details:
   - **Host**: Your Mac's IP address (e.g., `192.168.1.100`)
     - Find it: System Preferences → Network → IP Address
   - **Port**: Default is `8765` (match your Mac server)
   - **Token**: Your authentication token from the Mac server

3. **Tap "Save Configuration"** to persist settings
4. **Tap "Connect"** to establish connection

## 5. Finding Your Mac's IP Address

```bash
# On your Mac terminal:
ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}'
```

Or:
- System Preferences → Network → Select active connection (Wi-Fi/Ethernet)
- IP Address will be displayed

## 6. Using the App

### Once Connected:
- **Terminal Output**: Shows command results in green text on black background
- **Command Input**: Type commands at the bottom
- **Send Button**: Tap to execute (or press Enter)
- **History Button**: View and reuse previous commands
- **Auto-scroll**: Terminal automatically scrolls to latest output
- **Settings**: Tap gear icon to modify connection
- **Disconnect**: Tap X icon to disconnect

### Connection States:
- 🔴 **Red**: Error
- 🟠 **Orange**: Connecting...
- 🟢 **Green**: Connected
- ⚫ **Gray**: Disconnected

## 7. Troubleshooting

### Connection Issues

**"Connection refused"**
- Ensure Mac server is running on the specified port
- Check firewall settings on Mac
- Verify IP address and port are correct

**"Invalid configuration"**
- All fields must be filled
- Port must be between 1-65535
- Token cannot be empty

**"Authentication failed"**
- Verify token matches Mac server token
- Check for extra spaces in token field

### Build Issues

**"No Signing Certificate"**
- Select your Team in Signing & Capabilities
- Or use "Automatically manage signing"

**"Failed to prepare device"**
- Ensure device is unlocked
- Trust computer on iPhone if prompted
- Try unplugging and reconnecting

### Network Issues

**"Cannot connect to Mac on same network"**
- Both devices must be on same Wi-Fi network
- Check Mac firewall (System Preferences → Security & Privacy → Firewall)
- Try disabling VPN on either device

## 8. Testing the Connection

### Simple Test Commands:
```bash
# After connecting, try these commands:
pwd                    # Print working directory
ls -la                 # List files
echo "Hello from iOS!" # Echo test
whoami                 # Current user
```

### Expected Behavior:
- Commands appear in history
- Output shows immediately in terminal
- Green text confirms successful execution
- Errors appear in red (if any)

## 9. Advanced Features

### Command History
- Tap clock icon to view history
- Tap any command to reuse it
- Maximum 50 commands stored
- Cleared on app restart

### Auto-Reconnect
- Automatically attempts to reconnect if connection drops
- Up to 5 attempts with exponential backoff
- Manual reconnect always available

### Terminal Output
- 10,000 line buffer (auto-clears oldest)
- ANSI escape sequences stripped for clean display
- Text is selectable for copy/paste
- Auto-scroll can be toggled

## 10. Configuration Tips

### Save Multiple Profiles (Future Enhancement)
Currently, one configuration is saved. To switch servers:
1. Tap Settings gear icon
2. Enter new server details
3. Save and Connect

### Security Best Practices
- Keep token secure (stored in iOS Keychain)
- Use strong tokens on Mac server
- Only connect to trusted networks
- Don't share your token

## 11. File Locations

### Project Structure:
```
IphoneMacConnector/
├── IphoneMacConnector/           # App source code
│   ├── Models/                   # Data models
│   ├── Services/                 # Business logic
│   ├── Views/                    # UI components
│   └── Assets.xcassets/          # App assets
└── IphoneMacConnector.xcodeproj/ # Xcode project
```

### Runtime Data:
- **Saved Settings**: UserDefaults (automatic)
- **Token**: iOS Keychain (encrypted)
- **Command History**: In-memory (session only)

## 12. Development Tips

### Enable Debug Logging
The app prints debug messages to Xcode console:
- WebSocket connection events
- Keychain operations
- Reconnection attempts

### View Console Logs
In Xcode: View → Debug Area → Show Debug Area (⌘⇧Y)

### Hot Reload (SwiftUI Previews)
- Canvas: Editor → Canvas (⌥⌘↩)
- Live preview of UI changes
- Some views have Preview providers

## 13. Common Workflows

### Quick Connect:
1. Launch app
2. Tap "Load Saved Configuration"
3. Tap "Connect"

### Execute Command:
1. Type in command field
2. Tap Send or press Enter
3. View output in terminal

### Disconnect:
1. Tap X button
2. Confirm in alert
3. Returns to settings screen

### Clear Terminal:
1. Tap trash icon
2. Terminal output cleared immediately
3. Connection remains active

## 14. Performance Notes

- **Connection**: Typically connects in < 1 second on local network
- **Command Execution**: Near-instant response for simple commands
- **Memory Usage**: ~20-30MB typical
- **Battery Impact**: Minimal (WebSocket is efficient)
- **Network Usage**: Very low (text-only transmission)

## 15. Next Steps

After successful connection:
1. ✅ Test basic commands
2. ✅ Verify output display
3. ✅ Test command history
4. ✅ Try reconnection (disconnect Mac server, restart it)
5. ✅ Test on different networks
6. ✅ Configure firewall if needed

## 16. Getting Help

### Check These First:
- README.md - Full documentation
- IMPLEMENTATION_SUMMARY.md - Technical details
- Xcode console - Debug logs

### Common Solutions:
- **Restart app**: Clears state
- **Restart Mac server**: Fresh connection
- **Check network**: Same Wi-Fi for both devices
- **Verify firewall**: Allow incoming connections

## 17. Mac Server Setup

Ensure your Mac server (from the main project) is running:

```bash
# On Mac:
cd /Users/sooh/Devs/iphone_mac_connector/mac-server
python3 server.py --token YOUR_TOKEN
```

Look for:
```
WebSocket server started on ws://0.0.0.0:8765/terminal
```

## 18. Success Checklist

Before considering setup complete:
- [ ] App builds without errors
- [ ] App launches successfully
- [ ] Can enter connection settings
- [ ] Settings save/load works
- [ ] Can connect to Mac server
- [ ] Connection indicator turns green
- [ ] Can send commands
- [ ] Terminal shows output
- [ ] Command history works
- [ ] Can disconnect cleanly
- [ ] Auto-reconnect works after server restart

## Ready to Go!

Your iPhone-Mac Connector iOS app is now ready to use. Enjoy remote terminal access from your iPhone! 📱💻
