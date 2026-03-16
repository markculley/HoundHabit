build:
	/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
		-project Chat.xcodeproj \
		-scheme Chat \
		-destination 'generic/platform=iOS Simulator' \
		-allowProvisioningUpdates \
		build \
		| xcbeautify
