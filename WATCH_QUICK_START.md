# Apple Watch Integration - Quick Start

## ⚡️ 5-Minute Quick Start

### What You Need
- ✅ Mac with Xcode 15+
- ✅ iPhone (iOS 17+) for testing
- ✅ Apple Watch (watchOS 10+) paired to iPhone

### Step 1: Open Xcode (2 min)
```bash
cd /Users/sthompson/Development/KubbManager-Flutter-Local/kubb_manager/ios
open Runner.xcworkspace
```

### Step 2: Add watchOS Target (3 min)
1. Select project (blue icon) in navigator
2. Click "+" at bottom of targets list
3. Choose: watchOS → Watch App
4. Name: `KubbTrainerWatch`
5. Interface: SwiftUI
6. Click Finish

### Step 3: Link Watch App Files (2 min)
1. Delete Xcode-generated files in watch target folder
2. Right-click watch target → "Add Files to..."
3. Navigate to: `../watch/KubbTrainerWatch Watch App/`
4. Select all 3 `.swift` files
5. Uncheck "Copy items if needed"
6. Check the watch target
7. Click Add

### Step 4: Build & Test (5 min)
1. Select `KubbTrainerWatch Watch App` scheme
2. Select your Apple Watch as destination
3. Click Run (▶️)
4. Watch app installs and shows "Waiting for Session"

### Step 5: Test Integration (5 min)
1. Switch to `Runner` scheme
2. Select your iPhone
3. Run the iOS app
4. Start any training session
5. Look for watch icon in app bar
6. Tap it to enable watch mode
7. Record throws from your watch!

## ✅ Success!
If you see session details on your watch and can record throws, you're done!

## 📚 Full Documentation
- **Detailed setup:** `WATCH_SETUP_GUIDE.md`
- **Features & architecture:** `APPLE_WATCH_README.md`
- **Implementation details:** `IMPLEMENTATION_SUMMARY.md`
- **Code example:** `lib/examples/watch_mode_integration_example.dart`

## 🆘 Quick Troubleshooting

**Watch shows "iPhone Not Connected":**
- Restart both devices
- Check Bluetooth is on
- Verify devices are paired in Watch app

**Builds fail:**
- Clean build folder (Cmd+Shift+K)
- Check files are in correct targets
- Verify deployment targets (iOS 17+, watchOS 10+)

**Throws not recording:**
- Check watch shows session details (not "Waiting")
- Verify green dot (connected) on watch
- Check Xcode console for errors

## 🎯 Next Steps

Once basic testing works:
1. Add watch mode to all your training views
2. Customize watch UI if desired
3. Test battery usage
4. Prepare for App Store submission

Total time: ~20 minutes from start to working watch app! 🚀

