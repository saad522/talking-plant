# Build-time assets for PlantKokoro. Nothing from the venv ships.
#   make -C tools/kokoro assets
#   make -C tools/kokoro update-checksums   # after the assets changed on purpose
PYTHON ?= python3
VENV := .venv
STAMP := $(VENV)/.installed

.PHONY: assets update-checksums clean

assets: $(STAMP)
	$(VENV)/bin/python build_assets.py

update-checksums: $(STAMP)
	$(VENV)/bin/python build_assets.py --update-checksums

$(STAMP): requirements.txt
	$(PYTHON) -m venv $(VENV)
	$(VENV)/bin/pip install --quiet -r requirements.txt
	touch $(STAMP)

clean:
	rm -rf $(VENV) .cache
