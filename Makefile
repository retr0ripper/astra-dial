.PHONY: build test probe probe-list app run release appstore appstore-run icon clean

build:
	swift build

test:
	swift test
	swift test -Xswiftc -DAPP_STORE --scratch-path .build/appstore

probe:
	swift run astra-probe

probe-list:
	swift run astra-probe --list

app:
	Scripts/bundle.sh

run: app
	open "build/Astra Dial.app"

release:
	Scripts/release.sh

appstore:
	Scripts/appstore.sh

# The App Store variant, signed for local testing (no provisioning profile).
appstore-run:
	APPSTORE=1 Scripts/bundle.sh
	open "build/Astra Dial.app"

icon:
	swift Scripts/make-icon.swift Resources/AppIcon.icns

clean:
	rm -rf .build build
