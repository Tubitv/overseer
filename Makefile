FIXTURE_DIR=priv/fixture
SUBDIR=$(FIXTURE_DIR)/modules $(FIXTURE_DIR)/apps


test-prepare: $(SUBDIR)

$(SUBDIR):
	make -C $@

.PHONY: test-prepare $(SUBDIR)
