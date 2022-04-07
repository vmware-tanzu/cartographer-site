# Website for Cartographer.sh

## Prerequisites

- [Hugo](https://github.com/gohugoio/hugo)
  - macOS: `brew install hugo`
  - Windows: `choco install hugo-extended -confirm`

## Serve

```bash
make serve
```

Visit [http://localhost:1313](http://localhost:1313)

## Generate a Release

to create a release copy of `development` use

```bash
make release version=v1.2.3
```

The new version should appear in the site and be the default.

## Generating CRD Documentation

There is a tool, `./hack/crd.rb` designed to autogenerate CRD documentation based off the content of our Go doc-comments
in `/cartographer/pkg/apis`.

1. Check out cartographer locally, as a sibling of `cartographer-site`.

2. Ensure cartographer crd's are generated:

```shell
cd /path/to/cartographer
git co <revision you want to gen docs from>
make gen-manifests
```

3. Generate the site CRD reference:

```shell
cd /path/to/cartographer-site
make gen-crd-reference
```

4. review the changes to files in `/cartographer/site/content/docs/development/crds/*.yaml`
   1. Custom edits will be removed, so look for delta's that represent developer edits and roll those line's back

**Note:** the files in `./hack/crds` contain configuration for which fields to replace or ignore.
