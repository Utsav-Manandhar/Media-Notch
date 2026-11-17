# SwiftPM builds a bare binary; macOS needs a .app with Info.plist to ask for Spotify permission.
# The bundle is built inside .build (hidden from Spotlight) so the only copy Spotlight finds is the installed one.
APP = Media Notch.app

app:
	swift build -c release
	rm -rf ".build/$(APP)"
	mkdir -p ".build/$(APP)/Contents/MacOS"
	cp .build/release/Notch ".build/$(APP)/Contents/MacOS/"
	cp Info.plist ".build/$(APP)/Contents/"
	codesign --force -s - ".build/$(APP)"

# Installs into /Applications (so Spotlight and Launchpad can start it) and launches it.
run: app
	-pkill -x Notch
	rm -rf "/Applications/$(APP)"
	cp -R ".build/$(APP)" /Applications/
	open "/Applications/$(APP)"

test:
	swift test

.PHONY: app run test
