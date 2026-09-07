VERSION := $(shell cat VERSION)
ZIP := dist/rigor-v$(VERSION).zip

.PHONY: test dist clean

test:
	bash tests/test.sh

# Tracked files only (no .git, no dist), so the zip is exactly what the repo holds.
dist: test
	mkdir -p dist
	rm -f $(ZIP)
	git archive --format=zip --prefix=rigor-v$(VERSION)/ -o $(ZIP) HEAD
	unzip -l $(ZIP) | grep -q 'install.sh' || { echo "zip lacks install.sh"; exit 1; }
	unzip -l $(ZIP) | grep -q 'bin/rigor' || { echo "zip lacks bin/rigor"; exit 1; }
	@echo "built $(ZIP)"

clean:
	rm -rf dist
