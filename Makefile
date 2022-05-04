.PHONY: aws azure gcp ibm oci

PYTHON := $(shell command -v python3 2> /dev/null)
ifndef PYTHON
    PYTHON := $(shell command -v python 2> /dev/null)
endif

clean:
	@for trash in report/results/*.json report/results/*.txt report/results/*.tar report/results/*.tar.xz; do\
		if [ -f $$trash ] || [ -d $$trash ]; then \
			echo "Removing $$trash" ;\
			rm -rf $$trash ;\
		fi ; \
	done

