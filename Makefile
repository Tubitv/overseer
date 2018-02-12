FIXTURE_DIR=test/fixture
SUBDIR=$(FIXTURE_DIR)/modules $(FIXTURE_DIR)/apps


test-prepare: $(SUBDIR)

modules:
	make -C $(FIXTURE_DIR)/modules

apps:
	make -C $(FIXTURE_DIR)/apps

$(SUBDIR):
	make -C $@

.PHONY: test-prepare $(SUBDIR) modules apps
