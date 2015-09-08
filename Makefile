# Prepare variables
TMP = $(CURDIR)/tmp
VERSION = $(shell grep ^Version did.spec | sed 's/.* //')
PACKAGE = did-$(VERSION)
DOCS = $(TMP)/$(PACKAGE)/docs
EXAMPLES = $(TMP)/$(PACKAGE)/examples
CSS = --stylesheet=style.css --link-stylesheet
FILES = LICENSE README.rst \
		Makefile did.spec \
		docs examples did bin
ifndef USERNAME
    USERNAME = echo $$USER
endif


# Define special targets
all: docs packages
.PHONY: docs hooks tmp


# Run the test suite, optionally with coverage
test:
	py.test tests
coverage:
	coverage run --source=did,bin -m py.test tests
	coverage report


# Build documentation, prepare man page
docs: man
	cd docs && make html
man: tmp
	cp docs/header.txt $(TMP)/man.rst
	tail -n+7 README.rst | sed '/^Status/,$$d' >> $(TMP)/man.rst
	rst2man $(TMP)/man.rst | gzip > $(DOCS)/did.1.gz


# Build packages
tmp:
	mkdir -p $(TMP)/{SOURCES,$(PACKAGE)}
	cp -a $(FILES) $(TMP)/$(PACKAGE)
tarball: tmp test man
	cd $(TMP) && tar cfj SOURCES/$(PACKAGE).tar.bz2 $(PACKAGE)
rpm: tarball
	rpmbuild --define '_topdir $(TMP)' -bb did.spec
srpm: tarball
	rpmbuild --define '_topdir $(TMP)' -bs did.spec
packages: rpm srpm


# Git hooks and cleanup
hooks:
	ln -snf ../../hooks/pre-commit .git/hooks
	ln -snf ../../hooks/commit-msg .git/hooks
clean:
	rm -rf $(TMP)
	find did -name '*.pyc' -exec rm {} \;
	find tests -name '*.pyc' -exec rm {} \;
	cd docs && make clean
	rm -f .coverage


# Docker
run_docker: build_docker
	@echo
	@echo "Please note: this is a first cut at doing a container version as a result; known issues:"
	@echo "* kerberos auth may not be working correctly"
	@echo "* container runs as privileged to access the conf file"
	@echo "* output directory may not be quite right"
	@echo
	@echo "This does not actually run the docker image as it makes more sense to run it directly. Use:"
	@echo "docker run --privileged --rm -it -v $(HOME)/.did:/did.conf $(USERNAME)/did"
	@echo "If you want to add it to your .bashrc use this:"
	@echo "alias did=\"docker run --privileged --rm -it -v $(HOME)/.did:/did.conf $(USERNAME)/did\""
build_docker: examples/dockerfile
	docker build -t $(USERNAME)/did --file="examples/dockerfile" .
