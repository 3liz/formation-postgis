github-pages:
	@rm -rf docs/
	@mkdir docs/
	@cp logo.svg docs/
	@docker run --rm -w /plugin -v $(shell pwd):/plugin 3liz/pymarkdown:latest check_topology.md docs/check_topology.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin 3liz/pymarkdown:latest filter_data.md docs/filter_data.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin 3liz/pymarkdown:latest group_data.md docs/group_data.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin 3liz/pymarkdown:latest import_data.md docs/import_data.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin 3liz/pymarkdown:latest join_data.md docs/join_data.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin 3liz/pymarkdown:latest links_and_data.md docs/links_and_data.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin 3liz/pymarkdown:latest merge_geometries.md docs/merge_geometries.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin 3liz/pymarkdown:latest perform_calculation.md docs/perform_calculation.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin 3liz/pymarkdown:latest postgresql_in_qgis.md docs/postgresql_in_qgis.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin 3liz/pymarkdown:latest README.md docs/index.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin 3liz/pymarkdown:latest save_queries.md docs/save_queries.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin 3liz/pymarkdown:latest sql_select.md docs/sql_select.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin 3liz/pymarkdown:latest union.md docs/union.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin 3liz/pymarkdown:latest utils.md docs/utils.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin 3liz/pymarkdown:latest validate_geometries.md docs/validate_geometries.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin 3liz/pymarkdown:latest triggers.md docs/triggers.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin 3liz/pymarkdown:latest grant.md docs/grant.html
	@docker run --rm -w /plugin -v $(shell pwd):/plugin 3liz/pymarkdown:latest fdw.md docs/fdw.html
	@find docs/ -type f -name *.html | xargs sed -i "s#3liz.github.io#docs.3liz.org#g"
