.PHONY: build test probe probe-list app run clean

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

clean:
	rm -rf .build build
