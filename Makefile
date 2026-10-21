# Build, check and test commands for this Loup command-line application.
#
# On Linux x86-64 `loup` is the self-hosted driver and `loup-bootstrap` is
# Stage0; `check` and `test` need Stage0 there. On macOS, Windows and Linux
# arm64 both names run Stage0, so these targets work unchanged.

APP            ?= myapp
LOUP           ?= loup
LOUP_BOOTSTRAP ?= loup-bootstrap
BUILD_DIR      ?= build
BIN            := $(BUILD_DIR)/$(APP)
SOURCES        := package.lppkg $(shell find source -name '*.loup')
ARGS           ?=
TEST_ARGS      ?=

.PHONY: all run check test build ci clean

all: build

# Run from source, e.g. `make run ARGS="hello Ann --shout"`.
run:
	$(LOUP) run source/main.loup -- $(ARGS)

# Type-check source/main.loup and every module it imports.
check:
	$(LOUP_BOOTSTRAP) check --no-color

# Tests import project modules by their path under source/ (`from cli.args
# import (...)`), the same way the sources do, so source/ goes on LOUPPATH.
# Narrow the run with TEST_ARGS, e.g. `make test TEST_ARGS="--filter value"`.
test:
	LOUPPATH=source$${LOUPPATH:+:$$LOUPPATH} $(LOUP_BOOTSTRAP) test $(TEST_ARGS)

# Native executable (needs clang). Windows writes $(BIN).exe.
build: $(BIN)

$(BIN): $(SOURCES)
	@mkdir -p $(BUILD_DIR)
	$(LOUP) build --target native -o $@

# Everything CI runs, ending with a smoke test of the built binary.
ci: check test build
	$(BIN) --version

clean:
	rm -rf $(BUILD_DIR) .temp
