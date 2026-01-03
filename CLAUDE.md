# AI Glasses

iOS app for experimenting with Meta Ray-Ban smart glasses.

## Stack

- Swift 5 / SwiftUI
- Meta Wearables Device Access Toolkit (MWDATCore, MWDATCamera)
- Bluetooth LE for glasses connection

## SDK Documentation

- GitHub: https://github.com/facebook/meta-wearables-dat-ios
- Developer Center: https://developer.meta.com/docs/wearables

## Architecture

- `GlassesManager` - singleton for glasses connection and streaming
- `ContentView` - main UI with video preview and controls

## Key SDK Classes

- `Wearables.shared` - main entry point
- `AutoDeviceSelector` - automatic device selection
- `StreamSession` - video streaming and photo capture
- `VideoFrame.makeUIImage()` - convert frame to UIImage

## Requirements

- Physical iOS device (simulator doesn't support Bluetooth)
- Meta Ray-Ban AI glasses paired with device
- MetaAppID from https://developer.meta.com (add to Info.plist)
