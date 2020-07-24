github-pages:
	@rm -rf docs/
	@mkdir docs/
	@cp logo.svg docs/
	@docker run --rm -w /plugin -v $(shell pwd):/plugin etrimaille/pymarkdown check_topology.md docs/check_topology.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin etrimaille/pymarkdown filter_data.md docs/filter_data.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin etrimaille/pymarkdown group_data.md docs/group_data.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin etrimaille/pymarkdown import_data.md docs/import_data.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin etrimaille/pymarkdown join_data.md docs/join_data.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin etrimaille/pymarkdown links_and_data.md docs/links_and_data.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin etrimaille/pymarkdown merge_geometries.md docs/merge_geometries.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin etrimaille/pymarkdown perform_calculation.md docs/perform_calculation.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin etrimaille/pymarkdown postgresql_in_qgis.md docs/postgresql_in_qgis.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin etrimaille/pymarkdown README.md docs/index.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin etrimaille/pymarkdown save_queries.md docs/save_queries.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin etrimaille/pymarkdown sql_select.md docs/sql_select.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin etrimaille/pymarkdown union.md docs/union.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin etrimaille/pymarkdown utils.md docs/utils.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin etrimaille/pymarkdown validate_geometries.md docs/validate_geometries.html
