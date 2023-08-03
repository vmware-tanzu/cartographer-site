ADDLICENSE ?= go run -modfile hack/tools/go.mod github.com/google/addlicense
WOKE ?= go run -modfile hack/tools/go.mod github.com/get-woke/woke

ifeq ($(shell command -v yarn && echo yes),)
    $(error "Yarn (and node) must be installed")
endif

.PHONY: serve
serve:
	echo "Open docs at: http://localhost:1313"
	# wokeignore:rule=disable
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
		-ignore static/\*\* \
		-ignore content/docs/\*/crds/\*.yaml \
		-ignore content/docs/\*/tutorials/files/\*/\*.yaml \
		-ignore themes/\*\* \
		-ignore live-editor/node_modules/\*\* \
		.

.PHONY: woke
woke:
	#$(WOKE) -c https://via.vmw.com/its-woke-rules # Short URL currently offline
	$(WOKE) -c https://vmw-its-woke-client-rules-resources-prod.s3.us-west-2.amazonaws.com/public/its-woke-rules.yaml --exit-1-on-failure
