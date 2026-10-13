# Shared build rules for the Goalchemy-generated SDK types (sdk/gc*). The
# including Makefile sets MAKEFILE_DIR, GC_TYPE (the xtest SDK type) and
# GC_TARGET (the Goalchemy target name). Each src/<version> is a checkout or
# symlink of https://github.com/eugenioenko/opentdf-sdk; the build pins the
# Goalchemy revision from its references.lock.json (a release tag's commit,
# or a fix commit pinned ahead of its release), builds that compiler, runs
# the SDK's scripts/build-generated-<target>.sh and the target's CLI build,
# and installs dist/<version>/{otdfgc,cli.sh}. The Java, C#, C and Swift
# builds first install the pinned JDK, .NET, bdwgc or Swift toolchain under
# the Goalchemy checkout; C also needs libcurl, OpenSSL and zlib development
# packages (or the SDK's TDF3_CURL_PREFIX), Swift the same plus pkg-config.

# Targets whose native CLI build exists; the others fail with a clear message.
GC_BUILT_TARGETS := go typescript python java csharp rust c swift
# Toolchains the SDK's build scripts take from the Goalchemy checkout
# (scripts/fetch-toolchains.sh installs the pinned versions under .toolchains).
GC_TOOLCHAIN_go :=
GC_TOOLCHAIN_typescript :=
GC_TOOLCHAIN_python :=
GC_TOOLCHAIN_java := jdk
GC_TOOLCHAIN_csharp := dotnet
GC_TOOLCHAIN_rust :=
GC_TOOLCHAIN_c := bdwgc
GC_TOOLCHAIN_swift := swift
GOALCHEMY_GIT ?= https://github.com/eugenioenko/goalchemy.git
# A Goalchemy checkout to use when it is at the pinned revision (otherwise the
# sibling ../goalchemy of the SDK source, otherwise a clone).
GOALCHEMY_CHECKOUT ?=
GC_BUILD_DIR := $(MAKEFILE_DIR)/build
GC_GOALCHEMY_DIR := $(MAKEFILE_DIR)/../goalchemy

VERSIONS ?= $(shell find "$(MAKEFILE_DIR)/src" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) -not -name "*.git" -exec basename {} \;)

ifeq ($(strip $(VERSIONS)),)
$(error No versions found in the sdk/$(GC_TYPE)/src directory)
endif

.PHONY: all build clean

all: build
	@echo "Setup $(GC_TYPE) sdk clis for versions: $(VERSIONS)"

ifeq ($(filter $(GC_TARGET),$(GC_BUILT_TARGETS)),)
build:
	@echo "Error: $(GC_TYPE) ($(GC_TARGET)) is not built yet; only $(GC_BUILT_TARGETS) CLIs exist"
	@exit 1
else
build:
	@echo "Building $(GC_TYPE) binaries for versions: $(VERSIONS)"
	@for version in $(VERSIONS); do \
		echo "Building $(GC_TYPE) for $$version"; \
		src_real="$$(cd $(MAKEFILE_DIR)/src/$$version && pwd -P)"; \
		lock="$$src_real/references.lock.json"; \
		release=$$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["repositories"]["goalchemy"]["release"])' "$$lock") || exit 1; \
		revision=$$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["repositories"]["goalchemy"]["revision"])' "$$lock") || exit 1; \
		gcdir="$(GC_GOALCHEMY_DIR)/$$revision"; \
		if [ -n "$(GOALCHEMY_CHECKOUT)" ] && [ "$$(git -C "$(GOALCHEMY_CHECKOUT)" rev-parse HEAD 2>/dev/null)" = "$$revision" ]; then \
			gcdir="$$(cd "$(GOALCHEMY_CHECKOUT)" && pwd -P)"; \
		elif [ -d "$$src_real/../goalchemy" ] && [ "$$(git -C "$$src_real/../goalchemy" rev-parse HEAD 2>/dev/null)" = "$$revision" ]; then \
			gcdir="$$(cd "$$src_real/../goalchemy" && pwd -P)"; \
		elif [ ! -d "$$gcdir" ]; then \
			echo "  Cloning Goalchemy $$release at $$revision"; \
			git clone --quiet --no-checkout "$(GOALCHEMY_GIT)" "$$gcdir" || exit 1; \
			git -C "$$gcdir" checkout --quiet "$$revision" || exit 1; \
		fi; \
		if [ -n "$(GC_TOOLCHAIN_$(GC_TARGET))" ]; then \
			echo "  Installing the $(GC_TOOLCHAIN_$(GC_TARGET)) toolchain under $$gcdir/.toolchains"; \
			"$$gcdir/scripts/fetch-toolchains.sh" $(GC_TOOLCHAIN_$(GC_TARGET)) || exit 1; \
		fi; \
		compiler="$(GC_BUILD_DIR)/goalchemy-$$revision/goalchemy"; \
		if [ ! -x "$$compiler" ]; then \
			echo "  Building Goalchemy $$release from $$gcdir"; \
			mkdir -p "$$(dirname "$$compiler")"; \
			(cd "$$gcdir" && GOTOOLCHAIN=go1.25.14 go build -o "$$compiler" ./cmd/goalchemy) || exit 1; \
		fi; \
		generated="$(GC_BUILD_DIR)/$$version/generated"; \
		echo "  Generating the $(GC_TARGET) package into $$generated"; \
		GOALCHEMY_BIN="$$compiler" GOALCHEMY_DIR="$$gcdir" GOALCHEMY_ROOT="$$gcdir" "$$src_real/scripts/build-generated-$(GC_TARGET).sh" "$$generated" || exit 1; \
		mkdir -p $(MAKEFILE_DIR)/dist/$$version; \
		echo "  Building otdfgc into dist/$$version"; \
		GOALCHEMY_ROOT="$$gcdir" "$$src_real/scripts/build-$(GC_TARGET)-cli.sh" "$$generated" "$(MAKEFILE_DIR)/dist/$$version/otdfgc" || exit 1; \
		cp $(MAKEFILE_DIR)/../gc-cli.sh $(MAKEFILE_DIR)/dist/$$version/cli.sh || exit 1; \
	done
	@echo "All $(GC_TYPE) binaries built successfully"
endif

clean:
	@echo "Cleaning up $(GC_TYPE) builds"
	@rm -rf $(GC_BUILD_DIR) $(MAKEFILE_DIR)/dist
	@echo "Cleanup complete"
