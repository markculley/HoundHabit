SIMULATOR_ID = 2921F8F6-B772-4C33-876E-E0FDBFD9E06B
BUNDLE_ID = com.CometnCloud.HabitHound
XCODEBUILD = /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild
SIMCTL = /Applications/Xcode.app/Contents/Developer/usr/bin/simctl
DB_URL ?= $(shell cat .db_url 2>/dev/null)

.PHONY: emulator test build run sql-last-auth sql-last-sessions sql-storage

sql-last-auth:
	@test -n "$(DB_URL)" || (echo "Error: create a .db_url file containing your Supabase connection string"; exit 1)
	psql "$(DB_URL)" -f scripts/sql/auth_sessions.sql

sql-last-sessions:
	@test -n "$(DB_URL)" || (echo "Error: create a .db_url file containing your Supabase connection string"; exit 1)
	psql "$(DB_URL)" -v N=$(or $(N),10) -f scripts/sql/recent_sessions.sql

sql-storage:
	@test -n "$(DB_URL)" || (echo "Error: create a .db_url file containing your Supabase connection string"; exit 1)
	psql "$(DB_URL)" -f scripts/sql/storage_objects.sql

emulator:
	$(SIMCTL) boot $(SIMULATOR_ID) 2>/dev/null || true
	open -a Simulator

test:
	$(XCODEBUILD) \
		-project HabitHound.xcodeproj \
		-scheme HabitHound \
		-destination 'platform=iOS Simulator,id=$(SIMULATOR_ID)' \
		test \
		| xcbeautify

build:
	$(XCODEBUILD) \
		-project HabitHound.xcodeproj \
		-scheme HabitHound \
		-destination 'generic/platform=iOS Simulator' \
		-allowProvisioningUpdates \
		build \
		| xcbeautify

run:
	$(SIMCTL) boot $(SIMULATOR_ID) 2>/dev/null || true
	open -a Simulator
	$(XCODEBUILD) \
		-project HabitHound.xcodeproj \
		-scheme HabitHound \
		-destination 'platform=iOS Simulator,id=$(SIMULATOR_ID)' \
		-allowProvisioningUpdates \
		build \
		| xcbeautify
	$(SIMCTL) install $(SIMULATOR_ID) \
		$(shell find ~/Library/Developer/Xcode/DerivedData -name "HabitHound.app" -path "*iphonesimulator*" -not -path "*Index.noindex*" | head -1)
	$(SIMCTL) launch $(SIMULATOR_ID) $(BUNDLE_ID)
