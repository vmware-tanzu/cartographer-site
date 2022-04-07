.PHONY: deps
deps:
	yarn

.PHONY: build
build: deps
	yarn build

.PHONY: install
install:
	mkdir -p ../themes/template/static/live-editor
	rm -rf ../themes/template/static/live-editor/*
	cp -r dist/* ../themes/template/static/live-editor/

