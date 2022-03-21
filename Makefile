.PHONY: aws azure gcp ibm oci

PYTHON := $(shell command -v python3 2> /dev/null)
ifndef PYTHON
    PYTHON := $(shell command -v python 2> /dev/null)
endif

clean:
	@for trash in */results/*.json */results/*.txt; do\
		if [ -f $$trash ] || [ -d $$trash ]; then \
			echo "Removing $$trash" ;\
			rm -rf $$trash ;\
		fi ; \
	done

python: 
	@$(PYTHON) -m venv _build
	( \
		source _build/bin/activate; \
		_build/bin/python -m pip install --upgrade pip; \
		_build/bin/python -m pip install -r az/requirements.txt; \
	)
