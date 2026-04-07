SIMULATOR_ID = 2921F8F6-B772-4C33-876E-E0FDBFD9E06B
SIMULATOR_ID_17_PRO_Max = 8DC52374-CD06-4BEA-BD6E-19DB37D3ED20
BUNDLE_ID = com.CometnCloud.HabitHound
XCODEBUILD = /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild
SIMCTL = /Applications/Xcode.app/Contents/Developer/usr/bin/simctl
DB_URL ?= $(shell cat .db_url 2>/dev/null)

.PHONY: emulator emulator_iPhone17_Pro_Max test build run sql-last-auth sql-last-sessions sql-storage

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
	@echo "Booting iOS Simulator iPhone17 with ID: $(SIMULATOR_ID)"
	$(SIMCTL) boot $(SIMULATOR_ID) 2>/dev/null || true
	open -a Simulator

emulator_iPhone17_Pro_Max:
	@echo "Booting iOS Simulator iPhone 17 Pro Max with ID: $(SIMULATOR_ID_17_PRO_Max)"
	$(SIMCTL) boot $(SIMULATOR_ID_17_PRO_Max) 2>/dev/null || true
	open -a Simulator

test:
	$(XCODEBUILD) \
		-project HabitHound.xcodeproj \
		-scheme HabitHound \
		-destination 'platform=iOS Simulator,id=$(SIMULATOR_ID)' \
		test \
		| xcbeautify

list:
	@echo "***** Available Simulators:"
	$(SIMCTL) list devices
	@echo "***** Available Runtimes:"
	$(SIMCTL) list runtimes
	@echo "***** Available Device Types:"
	$(SIMCTL) list device_types
	
build:
	$(XCODEBUILD) \
		-project HabitHound.xcodeproj \
		-scheme HabitHound \
		-destination 'platform=iOS Simulator,id=$(SIMULATOR_ID)' \
		-allowProvisioningUpdates \
		build \
		| xcbeautify

run:
	$(SIMCTL) boot $(SIMULATOR_ID) 2>/dev/null || true
	$(SIMCTL) boot $(SIMULATOR_ID_17_PRO_Max) 2>/dev/null || true
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
	$(SIMCTL) install $(SIMULATOR_ID_17_PRO_Max) \
		$(shell find ~/Library/Developer/Xcode/DerivedData -name "HabitHound.app" -path "*iphonesimulator*" -not -path "*Index.noindex*" | head -1)
	$(SIMCTL) launch $(SIMULATOR_ID) $(BUNDLE_ID)
	$(SIMCTL) launch $(SIMULATOR_ID_17_PRO_Max) $(BUNDLE_ID)
