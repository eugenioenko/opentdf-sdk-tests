# Makefile

# Targets
GC_SDKS := gcgo gcts gcpy gcjava gccs gcrs gcc gcswift
.PHONY: all js go java $(GC_SDKS)

all: js go java
	@echo "Setup all sdk clis"

js:
	@echo "Building JavaScript SDK..."
	@cd js && make all
	@echo "JavaScript SDK built successfully"

go:
	@echo "Building Go SDK..."
	@cd go && make all
	@echo "Go SDK built successfully"

java:
	@echo "Building Java SDK..."
	@cd java && make all
	@echo "Java SDK built successfully"

# Goalchemy-generated SDK types; each builds from sdk/<type>/src/<version>
$(GC_SDKS):
	@echo "Building $@ SDK..."
	@cd $@ && make all
	@echo "$@ SDK built successfully"
