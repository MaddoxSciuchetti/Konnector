# Konnector

Minimal iOS 26 contact management app built with SwiftUI and SwiftData.

## Install on a connected iPhone

Connect and unlock the iPhone, enable Developer Mode, and trust this Mac. Replace `YOUR_TEAM_ID` with the Apple Developer Team ID shown in Xcode under **Settings → Accounts**, and update the device name if needed:

```sh
TEAM_ID=AB12C3DE45; DEVICE_NAME="iPhone von Emilian"; xcodebuild -project Konnector.xcodeproj -scheme Konnector -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath .build/DerivedData -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM_ID" EXCLUDED_SOURCE_FILE_NAMES=Assets.xcassets build && xcrun devicectl device install app --device "$DEVICE_NAME" .build/DerivedData/Build/Products/Debug-iphoneos/Konnector.app
```

The asset-catalog override works around the current Xcode/CoreSimulator version mismatch. Remove it after updating the local Xcode platform components. The first installation may also require selecting the same signing team for the Konnector target in Xcode.

## Run in Simulator with demo contacts

This opens Simulator, waits for its default iPhone to boot, builds and installs Konnector, then launches an isolated in-memory demo containing eight contacts:

```sh
open -a Simulator
for _ in {1..60}; do
  xcrun simctl list devices | grep -q '(Booted)' && break
  sleep 1
done
xcrun simctl bootstatus booted -b && \
xcodebuild -project Konnector.xcodeproj -scheme Konnector -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/SimulatorDerivedData EXCLUDED_SOURCE_FILE_NAMES=Assets.xcassets build && \
xcrun simctl install booted .build/SimulatorDerivedData/Build/Products/Debug-iphonesimulator/Konnector.app && \
(xcrun simctl terminate booted com.konnector.app 2>/dev/null || true) && \
xcrun simctl launch booted com.konnector.app --demo-data
```

If `simctl` reports that CoreSimulator is unavailable or out of date, update Xcode/macOS platform components or restart the Mac before retrying. Demo mode never requests Contacts permission and never writes to the production contact store.
