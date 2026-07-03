# Konnector

Minimal iOS 26 contact management app built with SwiftUI and SwiftData.

## Install on a connected iPhone

Connect and unlock the iPhone, enable Developer Mode, and trust this Mac. Replace `YOUR_TEAM_ID` with the Apple Developer Team ID shown in Xcode under **Settings → Accounts**, and update the device name if needed:

```sh
TEAM_ID=AB12C3DE45; DEVICE_NAME="iPhone von Emilian"; xcodebuild -project Konnector.xcodeproj -scheme Konnector -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath .build/DerivedData -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM_ID" EXCLUDED_SOURCE_FILE_NAMES=Assets.xcassets build && xcrun devicectl device install app --device "$DEVICE_NAME" .build/DerivedData/Build/Products/Debug-iphoneos/Konnector.app
```

The asset-catalog override works around the current Xcode/CoreSimulator version mismatch. Remove it after updating the local Xcode platform components. The first installation may also require selecting the same signing team for the Konnector target in Xcode.
