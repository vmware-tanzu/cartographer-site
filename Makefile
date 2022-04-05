ADDLICENSE ?= go run -modfile hack/tools/go.mod github.com/google/addlicense

.PHONY: serve
serve:
	echo "Open docs at: http://localhost:1313"
	hugo server --disableFastRender

.PHONY: release
release:
	if [ -z "$$version" ]; then echo "\nERROR: must provide version=v#.#.#\n" && exit 1; fi
	./hack/new-release.sh "$$version"

.PHONY: gen-crd-reference
gen-crd-reference:
	./hack/crds.rb

.PHONY: dev-dependencies
dev-dependencies:
	yarn install

.PHONY: update-live-editor
update-live-editor:
	$(MAKE) -C live-editor build install

.PHONY: lint
lint: dev-dependencies
	yarn lint

.PHONY: copyright
copyright:
	$(ADDLICENSE) \
		-f ./hack/boilerplate.go.txt \
		-ignore site/static/\*\* \
		-ignore site/content/docs/\*/crds/\*.yaml \
		-ignore site/content/docs/\*/tutorials/files/\*/\*.yaml \
		-ignore site/themes/\*\* \
		-ignore experimental/live-editor/node_modules/\*\* \
		.
