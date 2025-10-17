# Apple Watch Integration Setup Guide

This guide will walk you through setting up the Apple Watch companion app for Kubb Trainer.

## Prerequisites

- Xcode 15.0 or later
- iOS 17.0+ target
- watchOS 10.0+ target
- Paired Apple Watch for testing

## Step 1: Create watchOS Target in Xcode

1. **Open the iOS project in Xcode:**
   ```bash
   cd /Users/sthompson/Development/KubbManager-Flutter-Local/kubb_manager
   open ios/Runner.xcworkspace
   ```

2. **Add a watchOS target:**
   - In Xcode, select the project in the navigator (blue icon at the top)
   - Click the "+" button at the bottom of the targets list
   - Select "watchOS" → "Watch App"
   - Click "Next"

3. **Configure the watch target:**
   - Product Name: `KubbTrainerWatch`
   - Bundle Identifier: `com.kubb.manager.watch` (or match your app's identifier)
   - Organization Identifier: Match your existing app
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Include Notification Scene: **No** (we don't need it yet)
   - Click "Finish"

4. **Delete the default files** created by Xcode:
   - Delete `KubbTrainerWatchApp.swift` (Xcode generated)
   - Delete `ContentView.swift` (Xcode generated)
   - Delete `Assets.xcassets` (we'll configure later)

5. **Add our custom watch files:**
   - Right-click on `KubbTrainerWatch Watch App` folder
   - Select "Add Files to..."
   - Navigate to: `../watch/KubbTrainerWatch Watch App/`
   - Select all `.swift` files:
     - `KubbTrainerWatchApp.swift`
     - `WatchConnectivityManager.swift`
     - `ContentView.swift`
   - Make sure "Copy items if needed" is **unchecked** (we want to reference)
   - Make sure the watch target is **checked**
   - Click "Add"

## Step 2: Configure Watch App Settings

1. **Set deployment target:**
   - Select the `KubbTrainerWatch Watch App` target
   - Go to "General" tab
   - Set "Minimum Deployments" to **watchOS 10.0**

2. **Enable Watch Connectivity:**
   - Stay in the "General" tab
   - Scroll to "Frameworks, Libraries, and Embedded Content"
   - Verify `WatchConnectivity.framework` is present (should be automatic)

3. **Configure capabilities:**
   - Select the watch target
   - Go to "Signing & Capabilities" tab
   - Ensure your development team is selected
   - The watch app should automatically get the same capabilities as the iOS app

## Step 3: Configure iOS App for Watch Support

This has already been done by the setup scripts, but verify:

1. **Check Info.plist:**
   - Open `ios/Runner/Info.plist`
   - Verify these keys exist:
     ```xml
     <key>UIBackgroundModes</key>
     <array>
         <string>processing</string>
         <string>remote-notification</string>
     </array>
     <key>WKWatchConnectivityEnabled</key>
     <true/>
     ```

2. **Check AppDelegate.swift:**
   - Open `ios/Runner/AppDelegate.swift`
   - Verify `WatchConnectivityHandler` is imported and initialized

## Step 4: Build and Test

1. **Select the watch scheme:**
   - In Xcode, next to the Run/Stop buttons
   - Click the scheme dropdown
   - Select `KubbTrainerWatch Watch App`

2. **Select your Apple Watch as destination:**
   - Next to the scheme dropdown
   - Click the device dropdown
   - Select your paired Apple Watch

3. **Build and run:**
   - Click the ▶️ Run button or press `Cmd+R`
   - The watch app will install and launch
   - You should see "Waiting for Session" screen

4. **Run the iOS app:**
   - Switch back to the `Runner` scheme
   - Select your iPhone as destination
   - Run the iOS app

## Step 5: Testing Watch Mode

1. **Start a training session:**
   - Open the iOS app
   - Navigate to any training mode (8M Training, Inkast Blast, etc.)
   - Start a new session

2. **Enable Watch Mode:**
   - Look for the "Enable Watch Mode" button
   - Tap it to activate watch connectivity
   - The watch should immediately show the session details

3. **Test throw recording:**
   - On your watch, tap "HIT" or "MISS"
   - You should feel haptic feedback
   - The iPhone app should update in real-time
   - Session progress should update on both devices

## Troubleshooting

### Watch Shows "iPhone Not Connected"

**Causes:**
- iPhone and Watch not on same network
- Watch Connectivity not activated properly
- Background modes not enabled

**Solutions:**
1. Restart both devices
2. Verify iPhone and Watch are paired in Watch app
3. Check that iOS app is running (not just in background)
4. Check Xcode console for connection logs

### Throws Not Recording

**Check:**
1. Is watch showing session details? (not "Waiting for Session")
2. Does watch show green dot (connected)?
3. Check Xcode console for error messages
4. Verify `WatchConnectivityHandler.swift` is included in iOS target

### Build Errors

**"No such module 'WatchConnectivity'":**
- Make sure you're building for a physical device or simulator
- Check that WatchConnectivity framework is linked

**"Cannot find type 'WatchConnectivityHandler'":**
- Verify `WatchConnectivityHandler.swift` is in the iOS target (not watch target)
- Check the file is in the correct location: `ios/Runner/WatchConnectivityHandler.swift`

## Architecture Overview

```
iPhone App (Flutter)
    ↕️ Method Channel
iOS Bridge (Swift)
    ↕️ Watch Connectivity Framework
watchOS App (SwiftUI)
```

### Communication Flow

1. **Phone → Watch:** Session updates, context changes
2. **Watch → Phone:** Throw data, user inputs
3. **Bidirectional:** Connection state, error messages

### Data Sync Strategy

- **Immediate:** Uses `sendMessage()` when both devices are active
- **Deferred:** Uses `updateApplicationContext()` for when watch is asleep
- **Cached:** Watch stores throws locally if iPhone not reachable

## Next Steps

Once everything is working:

1. **Customize UI:** Edit `ContentView.swift` to adjust watch interface
2. **Add Assets:** Add app icons for watch in Assets.xcassets
3. **Test Different Modes:** Try all training modes with watch
4. **Battery Testing:** Test prolonged use to verify battery impact
5. **Production Build:** Create archive for App Store submission

## Support

If you encounter issues:

1. Check Flutter console: `flutter logs`
2. Check Xcode console for both iOS and watchOS targets
3. Enable debug logging in `WatchConnectivityService.dart`
4. Verify all files are in correct locations

## File Locations Reference

### Flutter Files (Dart)
- `lib/models/watch_session_state.dart` - Data models
- `lib/services/watch_connectivity_service.dart` - Main service
- `lib/services/watch_session_helper.dart` - Helper utilities

### iOS Files (Swift)
- `ios/Runner/WatchConnectivityHandler.swift` - iOS bridge
- `ios/Runner/AppDelegate.swift` - Integration point
- `ios/Runner/Info.plist` - Configuration

### watchOS Files (Swift)
- `watch/KubbTrainerWatch Watch App/KubbTrainerWatchApp.swift` - App entry point
- `watch/KubbTrainerWatch Watch App/WatchConnectivityManager.swift` - Watch connectivity
- `watch/KubbTrainerWatch Watch App/ContentView.swift` - Watch UI

