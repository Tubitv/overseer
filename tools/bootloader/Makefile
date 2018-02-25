PROJECT=bootloader
VERSION=$(strip $(shell cat version))

RELEASE_FILE=_build/prod/rel/$(PROJECT)/releases/$(VERSION)/$(PROJECT).tar.gz
TARGET_DIR=../ansible/roles/bootloader/files
FILE_NAME=$(shell basename $(RELEASE_FILE))

build:
	# make sure you build this under a ubuntu box
	@mix deps.get
	@MIX_ENV=prod mix compile
	@MIX_ENV=prod mix release --env=prod
	@cp $(RELEASE_FILE) $(TARGET_DIR)/$(FILE_NAME)
