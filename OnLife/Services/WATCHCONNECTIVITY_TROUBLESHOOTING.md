# WatchConnectivity Troubleshooting Checklist

## ✅ Code Fixes Applied

### 1. **Thread Safety** ✅
- Ensured WCSession.delegate is set on main thread
- Added main thread checks in both app initializers
- Added diagnostic logging

### 2. **Initialization Order** ✅
- Both apps initialize WatchConnectivityManager in `init()`
- Forced initialization before any views load
- Added 2-second delayed check for missed delegate callbacks

### 3. **Diagnostic Logging** ✅
- Added comprehensive status logging on startup
- Shows: paired status, installation status, activation state
- Emoji indicators for easy visual scanning

### 4. **Debug View** ✅
- Created `WatchConnectivityDebugView.swift`
- Shows real-time connection status
- Provides troubleshooting steps
- Test message sending capability

## 🔍 What to Check Now

### On Your Mac/Xcode:

1. **Clean Build Folder**
   ```
   Xcode → Product → Clean Build Folder (⌘⇧K)
   ```

2. **Verify Bundle IDs**
   - iPhone target → General → Bundle Identifier
   - Should be: `com.onlife.OnLife` (or your actual ID)
   - Watch App target → General → Bundle Identifier  
   - Should be: `com.onlife.OnLife.watchkitapp`
   - Watch Extension target → General → Bundle Identifier
   - Should be: `com.onlife.OnLife.watchkitapp.extension`

3. **Check Info.plist (Watch Extension)**
   - Open Watch Extension's Info.plist
   - Verify these keys exist:
     ```xml
     <key>WKCompanionAppBundleIdentifier</key>
     <string>com.onlife.OnLife</string>
     
     <key>WKExtension</key>
     <dict>
         <key>WKAppBundleIdentifier</key>
         <string>com.onlife.OnLife.watchkitapp</string>
     </dict>
     ```

4. **Check Target Membership**
   - Select `WatchConnectivityManager.swift`
   - File Inspector (⌘⌥1)
   - Target Membership should include:
     - ✅ OnLife (iPhone)
     - ✅ OnLife Watch Extension

### On Your iPhone:

1. **Check Pairing**
   ```
   Settings → Bluetooth → Look for "Apple Watch"
   Should show: Connected
   ```

2. **Check Watch App List**
   ```
   Watch app → My Watch → Scroll down
   Look for "OnLife" in the app list
   Toggle should be ON (green)
   ```

3. **Delete Both Apps**
   ```
   - Delete OnLife from iPhone
   - Delete OnLife from Watch (long press)
   ```

### On Your Apple Watch:

1. **Check Bluetooth**
   ```
   Settings → Bluetooth
   Should show: Connected to iPhone
   Green phone icon should be visible in Control Center
   ```

2. **Check Installation**
   ```
   Apps screen → Look for OnLife
   If not visible, install from iPhone's Watch app
   ```

## 🚀 Installation Procedure

Follow this EXACT order:

1. **Clean Everything**
   ```
   a. Force quit both apps
   b. Delete from both devices
   c. Xcode → Product → Clean Build Folder
   d. Restart Xcode
   ```

2. **Rebuild**
   ```
   a. Select iPhone scheme
   b. Build & Run on iPhone (⌘R)
   c. Wait for app to launch completely
   d. Select Watch scheme  
   e. Build & Run on Watch (⌘R)
   f. Wait for Watch app to install & launch
   ```

3. **Verify Installation**
   ```
   a. Check Console in Xcode
   b. Filter logs by "WatchConnectivity"
   c. Look for these lines:
   
   iPhone should show:
   📱📱📱 [OnLifeApp] init() STARTING 📱📱📱
   🔧 [WatchConnectivity] Activating WCSession...
   🔔🔔🔔 [WatchConnectivity] activationDidCompleteWith CALLED! 🔔🔔🔔
   ✅ [WatchConnectivity] Session activated: true
   📱 [WatchConnectivity] Paired: true, Installed: true, Reachable: true
   
   Watch should show:
   ⌚⌚⌚ [OnLifeWatchApp] init() STARTING ⌚⌚⌚
   🔧 [WatchConnectivity] Activating WCSession...
   🔔🔔🔔 [WatchConnectivity] activationDidCompleteWith CALLED! 🔔🔔🔔
   ✅ [WatchConnectivity] Session activated: true
   ⌚ [WatchConnectivity] Reachable: true
   ```

4. **If Still Not Working**
   ```
   a. Restart iPhone (full power cycle)
   b. Restart Watch (hold side button → Power Off)
   c. Wait 30 seconds
   d. Repeat step 2
   ```

## 🔬 Using the Debug View

Add this to your iPhone app (e.g., in Settings):

```swift
NavigationLink("WatchConnectivity Debug") {
    WatchConnectivityDebugView()
}
```

The debug view shows:
- Real-time pairing status
- Installation verification
- Activation state
- Test message button
- Troubleshooting steps

## 📊 Expected Console Output

### ✅ GOOD (Working):
```
📱 [OnLifeApp] WatchConnectivityManager initialized
🔧 [WatchConnectivity] Activating WCSession...
   Thread: MAIN ✅
   Delegate set: ✅
   State after activate(): 2
   isPaired: true
   isWatchAppInstalled: true
   isReachable: true
🔔🔔🔔 [WatchConnectivity] activationDidCompleteWith CALLED! 🔔🔔🔔
   State: 2
✅ [WatchConnectivity] Session activated: true
```

### ❌ BAD (Not Working):
```
📱 [OnLifeApp] WatchConnectivityManager initialized
🔧 [WatchConnectivity] Activating WCSession...
   Thread: MAIN ✅
   Delegate set: ✅
   State after activate(): 0
   isPaired: true
   isWatchAppInstalled: false  ← PROBLEM HERE
   isReachable: false
⏱️ [WatchConnectivity] 2-second status check:
   Activation state: 0
   → Watch app NOT INSTALLED!  ← PROBLEM DIAGNOSIS
```

## 🛠️ Common Issues & Solutions

### Issue: "Watch app NOT INSTALLED"
**Solution:**
1. iPhone Watch app → My Watch → OnLife → Toggle OFF then ON
2. Or: Delete from Watch, reinstall from Xcode
3. Verify Watch scheme is building the Watch Extension target

### Issue: "activationDidCompleteWith never called"
**Solution:**
1. Verify delegate is set on main thread (fixed in code)
2. Check if WCSession.isSupported() returns false
3. Try restarting both devices

### Issue: "isPaired: false"
**Solution:**
1. Unpair and re-pair Watch with iPhone
2. Settings → Bluetooth → Forget "Apple Watch"
3. Watch app → Unpair Apple Watch
4. Re-pair from scratch

### Issue: "Delegate: false"
**Solution:**
1. This is a critical bug - the delegate wasn't set
2. Our code now ensures this on main thread
3. If still happens, there's a threading race condition

## 📱 Add Debug View to Your App

In your `SettingsView.swift` or similar:

```swift
NavigationLink {
    WatchConnectivityDebugView()
} label: {
    HStack {
        Image(systemName: "applewatch")
        Text("WatchConnectivity Debug")
        Spacer()
        if !connectivity.isSessionActivated {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
        }
    }
}
```

## 🎯 Success Criteria

You'll know it's working when:

1. ✅ Console shows "activationDidCompleteWith CALLED" on BOTH devices
2. ✅ Activation state: 2 (activated) on both devices
3. ✅ isReachable: true after a few seconds
4. ✅ Debug view shows all green checkmarks
5. ✅ Test message succeeds in debug view

## 📞 Still Not Working?

If after following ALL steps above it still doesn't work:

1. **Check Console Output**
   - Copy ALL logs with "[WatchConnectivity]" 
   - Look for the 2-second diagnostic message
   - It will tell you exactly what's wrong

2. **Verify Physical Setup**
   - Both devices on same WiFi
   - Bluetooth enabled on both
   - Green phone icon on Watch
   - Watch not in Airplane Mode

3. **Nuclear Option**
   - Unpair Watch completely
   - Re-pair as new Watch
   - Reinstall app
   - This fixes 99% of persistent issues
