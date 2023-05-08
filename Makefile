-include Makefile.local # for optional local options

NAME = translater
COMPILER ?= crystal
SHARDS ?= shards

ENTRY != cat shard.yml |grep main: |cut -d: -f2|cut -d" " -f2
ENTRY_PATH := $(shell pwd)/$(shell cat shard.yml |grep main: |cut -d: -f2|cut -d" " -f2)

CACHE_DIR != ${COMPILER} env CRYSTAL_CACHE_DIR
CACHE_DIR := $(CACHE_DIR)/$(subst /,-,${shell echo ${ENTRY_PATH} |cut -c2-})

FLAGS ?= --progress -Dstrict_multi_assign -Dno_number_autocast
RELEASE_FLAGS ?= --progress --production --release -Dstrict_multi_assign -Dno_number_autocast

# INSTALL:
DESTDIR ?= /usr/local
BINDIR ?= $(DESTDIR)/bin
INSTALL ?= /usr/bin/install

SRC_SOURCES != find src -name '*.cr'
LIB_SOURCES != find lib -name '*.cr' 2>/dev/null
SPEC_SOURCES != find spec -name '*.cr' 2>/dev/null

O := bin/$(NAME)

.PHONY: build
build: ## Build the application binary.
build: $(O)

$(O): $(SRC_SOURCES) $(LIB_SOURCES) lib
	mkdir -p $(shell dirname $@)
	$(COMPILER) build $(FLAGS) $(ENTRY) -o $(O)

.PHONY: release
release: ## Build release binary.
release: lib
	$(COMPILER) build $(RELEASE_FLAGS) $(ENTRY) -o $(O)

.PHONY: spec
spec: ## Run spec suite.
spec: lib
	$(COMPILER) spec $(FLAGS) --order=random --error-on-warnings

.PHONY: format
format: ## Apply source code formatting
format: $(SRC_SOURCES) $(SPEC_SOURCES)
	$(CRYSTAL) tool format src spec

docs: ## Generate API docs
docs: $(SRC_SOURCES) lib
	$(CRYSTAL) docs

.PHONY: install
install: $(O) ## Install the compiler at DESTDIR
	$(INSTALL) -d -m 0755 "$(BINDIR)/"
	$(INSTALL) -m 0755 "$(O)" "$(BINDIR)/$(NAME)"
.PHONY: uninstall
uninstall: ## Uninstall the compiler from DESTDIR
	rm -f "$(BINDIR)/$(NAME)"

.PHONY: check
check: ## Verify all dependencies are installed and unused removed.
check:
	$(SHARDS) check || $(SHARDS) install
	$(SHARDS) prune


lib: shard.lock
	$(SHARDS) install

shard.lock: shard.yml
	$(SHARDS) update

.PHONY: clean
clean:
	@rm -f $(O)

.PHONY: cleanall
cleanall: clean
	@rm -rf ${CACHE_DIR}

.PHONY: help
help: ## Show this help
	@echo
	@printf '\033[34mtargets:\033[0m\n'
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) |\
		sort |\
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo
	@printf '\033[34moptional variables:\033[0m\n'
	@grep -hE '^[a-zA-Z_-]+ \?=.*?## .*$$' $(MAKEFILE_LIST) |\
		sort |\
		awk 'BEGIN {FS = " \\?=.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo
	@printf '\033[34mrecipes:\033[0m\n'
	@grep -hE '^##.*$$' $(MAKEFILE_LIST) |\
		awk 'BEGIN {FS = "## "}; /^## [a-zA-Z_-]/ {printf "  \033[36m%s\033[0m\n", $$2}; /^##  / {printf "  %s\n", $$2}'
