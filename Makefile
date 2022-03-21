.PHONY: aws azure gcp ibm oci

clean:
	@for trash in */results/*.json */results/*.txt; do\
		if [ -f $$trash ] || [ -d $$trash ]; then \
			echo "Removing $$trash" ;\
			rm -rf $$trash ;\
		fi ; \
	done

python: 
	@python -m venv _build
	( \
		source _build/bin/activate; \
		python -m pip install --upgrade pip; \
		python -m pip install -r az/requirements.txt; \
	)
