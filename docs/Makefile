DIAGRAMS_DIR := diagrams
BUILD_DIR    := build

PDFLATEX     := pdflatex
PDFTOCAIRO   := pdftocairo

TEX_SRCS     := $(wildcard $(DIAGRAMS_DIR)/*.tex)
SVG_TARGETS  := $(patsubst $(DIAGRAMS_DIR)/%.tex, $(DIAGRAMS_DIR)/%.svg, $(TEX_SRCS))

.PHONY: all diagrams clean distclean test

all: diagrams

diagrams: $(SVG_TARGETS)
	@echo "All diagrams built successfully in $(DIAGRAMS_DIR)/"

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

$(DIAGRAMS_DIR)/%.svg: $(DIAGRAMS_DIR)/%.tex | $(BUILD_DIR)
	@echo "[LATEX] Compiling $< -> $(BUILD_DIR)/$*.pdf..."
	@$(PDFLATEX) -interaction=nonstopmode -halt-on-error -output-directory=$(BUILD_DIR) $< > $(BUILD_DIR)/$*.log 2>&1 || \
		(echo "ERROR: Compilation of $< failed. Log output:"; tail -n 25 $(BUILD_DIR)/$*.log; exit 1)
	@echo "[SVG]   Converting $(BUILD_DIR)/$*.pdf -> $@..."
	@$(PDFTOCAIRO) -svg $(BUILD_DIR)/$*.pdf $@
	@echo "[DONE]  $@"

clean:
	@echo "Cleaning temporary LaTeX build artifacts in $(BUILD_DIR)..."
	@rm -rf $(BUILD_DIR)

distclean: clean
	@echo "Removing generated SVG files in $(DIAGRAMS_DIR)..."
	@rm -f $(SVG_TARGETS)

# Verify diagram builds and ensure reslting SVGs have no uncommitted diffs
test:
	@echo "Testing diagram compilation..."
	@$(MAKE) -s clean
	@$(MAKE) -s -B diagrams
	@for svg in $(SVG_TARGETS); do \
		if [ ! -s "$$svg" ]; then \
			echo "ERROR: $$svg was not generated or is empty!"; \
			exit 1; \
		fi; \
	done
	@echo "Checking that generated SVGs match checked-in files..."
	@for tex in $(TEX_SRCS); do \
		if git ls-files --error-unmatch "$$tex" >/dev/null 2>&1; then \
			svg="$${tex%.tex}.svg"; \
			if ! git ls-files --error-unmatch "$$svg" >/dev/null 2>&1; then \
				echo "ERROR: $$tex is tracked in git, but $$svg is not checked in!"; \
				echo "Please run 'make diagrams' (or 'make update_diagrams') and git add $$svg."; \
				exit 1; \
			fi; \
		fi; \
	done
	@if ! git diff --exit-code -- $(SVG_TARGETS); then \
		echo "ERROR: Generated SVG files differ from checked-in files."; \
		echo "Please run 'make diagrams' (or 'make update_diagrams') and commit the updated SVGs."; \
		exit 1; \
	fi
	@echo "All diagram tests passed (no SVG diffs)!"
