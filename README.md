name: Build iOS App
on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode.app

      - name: Build
        run: |
          xcodebuild \
            -project IO-Tools/MyApp.xcodeproj \
            -scheme MyApp \
            -sdk iphonesimulator \
            -configuration Debug \
            build