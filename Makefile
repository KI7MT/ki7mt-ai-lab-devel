# Makefile for ki7mt-ai-lab-devel
#
# Meta-package for KI7MT AI Lab development environment

SHELL := /bin/bash
.PHONY: help srpm rpm clean info

NAME        := ki7mt-ai-lab-devel
VERSION     := $(shell cat VERSION 2>/dev/null || echo "0.0.0")
SPEC        := $(NAME).spec
SRPM_DIR    := ~/rpmbuild/SRPMS
RPM_DIR     := ~/rpmbuild/RPMS/noarch

.DEFAULT_GOAL := help

help:
	@printf "\n"
	@printf "┌─────────────────────────────────────────────────────────────────┐\n"
	@printf "│  $(NAME) v$(VERSION)                              │\n"
	@printf "│  Development Environment Meta-Package                          │\n"
	@printf "└─────────────────────────────────────────────────────────────────┘\n"
	@printf "\n"
	@printf "Targets:\n"
	@printf "  help      Show this help message\n"
	@printf "  info      Show package dependencies\n"
	@printf "  srpm      Build source RPM\n"
	@printf "  rpm       Build binary RPM\n"
	@printf "  clean     Remove build artifacts\n"
	@printf "\n"
	@printf "Prerequisites:\n"
	@printf "  - NVIDIA CUDA repo configured\n"
	@printf "  - ClickHouse repo configured\n"
	@printf "  - EPEL repo enabled\n"
	@printf "\n"

info:
	@printf "\n"
	@printf "Package: $(NAME) v$(VERSION)\n"
	@printf "\n"
	@printf "Dependencies:\n"
	@grep "^Requires:" $(SPEC) | sed 's/Requires:/  -/' | sort
	@printf "\n"

srpm:
	@printf "Building SRPM...\n"
	rpmbuild -bs $(SPEC) \
		--define "_sourcedir $(CURDIR)" \
		--define "version $(VERSION)"
	@printf "SRPM: $(SRPM_DIR)/$(NAME)-$(VERSION)*.src.rpm\n"

rpm:
	@printf "Building RPM...\n"
	rpmbuild -bb $(SPEC) \
		--define "_sourcedir $(CURDIR)" \
		--define "version $(VERSION)"
	@printf "RPM: $(RPM_DIR)/$(NAME)-$(VERSION)*.rpm\n"

clean:
	@printf "Cleaning build artifacts...\n"
	rm -rf build/ dist/
	@printf "Clean complete.\n"
