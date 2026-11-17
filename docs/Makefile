DIAGRAMS_DIR := diagrams
DRAWIO_SRC   := $(DIAGRAMS_DIR)/mas.drawio

# draw.io desktop CLI; runs headless under xvfb-run when no X display is available
DRAWIO       := drawio
DRAWIO_FLAGS := --transparent --no-sandbox --disable-gpu
XVFB_RUN     := $(if $(DISPLAY),,xvfb-run -a)
PYTHON       := python3

# <svg name>:<1-based page index in mas.drawio>
# Pages: 1 Top, 2 Zicsr, 3 ECALL, 4 Pipelined (image, not exported)
PAGES        := top:1 zicsr:2 ecall:3
SVG_TARGETS  := $(foreach p,$(PAGES),$(DIAGRAMS_DIR)/$(firstword $(subst :, ,$(p))).svg)

page_index = $(lastword $(subst :, ,$(filter $(1):%,$(PAGES))))

.PHONY: all diagrams distclean test

all: diagrams

diagrams: $(SVG_TARGETS)
	@echo "All diagrams exported successfully in $(DIAGRAMS_DIR)/"

$(DIAGRAMS_DIR)/%.svg: $(DRAWIO_SRC) scripts/embed_svg_fonts.py $(wildcard fonts/*.woff2)
	@echo "[SVG]   Exporting page $(call page_index,$*) of $< -> $@..."
	@# Electron logs harmless dbus errors when headless; only show its output on failure
	@$(XVFB_RUN) $(DRAWIO) --export --format svg --page-index $(call page_index,$*) \
		--output $@ $< $(DRAWIO_FLAGS) > $@.log 2>&1 || (cat $@.log; rm -f $@.log; exit 1)
	@rm -f $@.log
	@echo "[FONT]  Embedding fonts in $@..."
	@$(PYTHON) scripts/embed_svg_fonts.py $@
	@echo "[DONE]  $@"

distclean:
	@echo "Removing generated SVG files in $(DIAGRAMS_DIR)..."
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
