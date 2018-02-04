APPS=example_app example_complex_app

build: $(APPS)
	@echo bad file > tarball/corrupted.tar.gz

$(APPS):
	make -C $@

.PHONY: build $(APPS)
