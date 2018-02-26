RELEASE_FILE=_build/prod/rel/example_complex_app/releases/0.1.0/example_complex_app.tar.gz
TARGET_DIR=../tarball
FILE_NAME=$(shell basename $(RELEASE_FILE))
build:
	@mix deps.get
	@MIX_ENV=prod mix compile
	@MIX_ENV=prod mix release --env=prod
	@cp $(RELEASE_FILE) $(TARGET_DIR)/$(FILE_NAME)
