DIAGRAMS_DIR := diagrams
BLOCK_DIR    := $(DIAGRAMS_DIR)/block
TIMING_DIR   := $(DIAGRAMS_DIR)/timing
DRAWIO_SRC   := $(DIAGRAMS_DIR)/mas.drawio

# draw.io desktop CLI; runs headless under xvfb-run when no X display is available
DRAWIO       := drawio
DRAWIO_FLAGS := --transparent --no-sandbox --disable-gpu
XVFB_RUN     := $(if $(DISPLAY),,xvfb-run -a)
PYTHON       := python3

# Block diagrams: one SVG per page of mas.drawio
# <svg name>:<1-based page index in mas.drawio>
# Pages: 1 Top, 2 Fetch stage, 3 Zicsr, 4 ECALL
PAGES        := top:1 fetch_stage:2 zicsr:3 ecall:4
BLOCK_SVGS   := $(foreach p,$(PAGES),$(BLOCK_DIR)/$(firstword $(subst :, ,$(p))).svg)

# Timing diagrams: one SVG per WaveDrom JSON source (requires `pip install wavedrom`)
TIMING_SRC   := $(wildcard $(TIMING_DIR)/*.json)
TIMING_SVGS  := $(TIMING_SRC:.json=.svg)

SVG_TARGETS  := $(BLOCK_SVGS) $(TIMING_SVGS)

page_index = $(lastword $(subst :, ,$(filter $(1):%,$(PAGES))))

.PHONY: all diagrams block timing distclean test

all: diagrams

diagrams: block timing

block: $(BLOCK_SVGS)
	@echo "All block diagrams exported successfully in $(BLOCK_DIR)/"

timing: $(TIMING_SVGS)
	@echo "All timing diagrams rendered successfully in $(TIMING_DIR)/"

$(BLOCK_DIR)/%.svg: $(DRAWIO_SRC) scripts/embed_svg_fonts.py $(wildcard fonts/*.woff2)
	@echo "[SVG]   Exporting page $(call page_index,$*) of $< -> $@..."
	@mkdir -p $(BLOCK_DIR)
	@# Electron logs harmless dbus errors when headless; only show its output on failure
	@$(XVFB_RUN) $(DRAWIO) --export --format svg --page-index $(call page_index,$*) \
		--output $@ $< $(DRAWIO_FLAGS) > $@.log 2>&1 || (cat $@.log; rm -f $@.log; exit 1)
	@rm -f $@.log
	@echo "[FONT]  Embedding fonts in $@..."
	@$(PYTHON) scripts/embed_svg_fonts.py $@
	@echo "[DONE]  $@"

$(TIMING_DIR)/%.svg: $(TIMING_DIR)/%.json scripts/render_wavedrom.py
	@echo "[WAVE]  Rendering $< -> $@..."
	@$(PYTHON) scripts/render_wavedrom.py $< $@
	@echo "[DONE]  $@"

distclean:
	@echo "Removing generated SVG files in $(BLOCK_DIR) and $(TIMING_DIR)..."
	@rm -f $(SVG_TARGETS)

# Verify diagram export and ensure resulting SVGs have no uncommitted diffs
test:
	@echo "Testing diagram export..."
	@$(MAKE) -s -B diagrams
	@for svg in $(SVG_TARGETS); do \
		if [ ! -s "$$svg" ]; then \
			echo "ERROR: $$svg was not generated or is empty!"; \
			exit 1; \
		fi; \
		if ! git ls-files --error-unmatch "$$svg" >/dev/null 2>&1; then \
			echo "ERROR: $$svg is not checked in!"; \
			echo "Please run 'make diagrams' and git add $$svg."; \
			exit 1; \
		fi; \
	done
	@echo "Checking that exported SVGs match checked-in files..."
	@if ! git diff --exit-code -- $(SVG_TARGETS); then \
		echo "ERROR: Exported SVG files differ from checked-in files."; \
		echo "Please run 'make diagrams' and commit the updated SVGs."; \
		exit 1; \
	fi
	@echo "All diagram tests passed (no SVG diffs)!"
