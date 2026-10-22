.PHONY: build test probe probe-list app run release icon clean

build:
	swift build

test:
	swift test

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

icon:
	swift Scripts/make-icon.swift Resources/AppIcon.icns

clean:
	rm -rf .build build
