# Testing Templates

`cartotest` is a CLI tool to assert that your Cartographer templates behave as you expect.

## Quick Start

### Install

Clone the Cartographer repository:

```shell
git clone git@github.com:vmware-tanzu/cartographer.git
cd cartographer
```

Install the cartotest CLI:

```shell
go install ./cmd/cartotest
```

### Run

Run the example template tests:

```shell
cartotest --directory ./tests/templates/
```

You should see

```console
PASS: tests/templates/deliverable/regular-template
PASS: tests/templates/deliverable/ytt-preprocess
PASS: tests/templates/deliverable/ytt-template
PASS: tests/templates/kpack
PASS
```

Great, a passing test!

### Failing Tests

Now let's make a test fail.

The folder ./tests/templates/kpack tests the `template.yaml` file. The `expected.yaml` file is what we are asserting
should be created by Cartographer. There are two files that are used as inputs to the template. These are
`workload.yaml` and `info.yaml`.

Let's alter the workload so that what is stamped out by Cartographer will be different from `expected.yaml`.

_The example edit uses mikefarah/yq for which you can find installation instructions
[here](https://github.com/mikefarah/yq#install). Alternatively you can manually change the `metadata.name` field of
`./tests/templates/kpack/workload.yaml` to `another-identifier`._

```shell
yq '.metadata.name = "another-identifier"' ./tests/templates/kpack/workload.yaml -i
```

Run cartotests again:

```shell
cartotest --directory ./tests/templates/
```

```console
PASS: tests/templates/deliverable/regular-template
PASS: tests/templates/deliverable/ytt-preprocess
PASS: tests/templates/deliverable/ytt-template
FAIL: tests/templates/kpack
FAIL
```

Let's get some more detail about the tests by running cartotest in verbose mode:

```shell
cartotest --directory ./tests/templates/ -v
```

```console
DEBU[0000] populate info failed, did not find tests/templates/info.yaml

PASS: tests/templates/deliverable/regular-template
PASS: tests/templates/deliverable/ytt-preprocess
PASS: tests/templates/deliverable/ytt-template
FAIL: tests/templates/kpack
Name: image-template
Description: template requiring 'source' input
Error: expected does not equal actual: (-expected +actual):
		map[string]any{
		      "apiVersion": string("kpack.io/v1alpha2"),
		      "kind":       string("Image"),
-	      "metadata":   map[string]any{"name": string("my-workload-name")},
+	      "metadata":   map[string]any{"name": string("another-identifier")},
		      "spec": map[string]any{
		              "builder":            map[string]any{"kind": string("ClusterBuilder"), "name": string("go-builder")},
		              "serviceAccountName": string("cartographer-example-registry-creds-sa"),
		              "source":             map[string]any{"blob": map[string]any{"url": string("some-passed-on-url")}},
		              "tag": strings.Join({
		                      "some-default-prefix-",
-	                      "my-workload-name",
+	                      "another-identifier",
		              }, ""),
		      },
		}
```

We can see much more information about the failing test: the name, description and the actual error. We can see how
changing the name of the workload has changed the output of Cartographer from the expected state. For example, the
`spec.tag` field was expected to be a join of `some-default-prefix-` and `my-workload-name` but was instead a join of
`some-default-prefix-` and `another-identifier`.

Let's set the workload back to its original state:

```shell
git checkout ./tests/templates/kpack/workload.yaml
```

## Reference

There are 7 types of information with which a cartotest may be configured. Those with an asterix (\*) are required.

- [Template \*](#template): The template under test
- [Workload \*](#workload): The workload that will pair with the supply chain/template
- [Expected \*](#expected): The expected object that will be created by Cartographer
- [Supply Chain Inputs](#supply-chain-inputs): The sources/images/configs assumed to have been created earlier in a
  supply chain
- [Blueprint Params](#blueprint-params): The params specified in the supply chain
- [YTT Preprocessing File](#ytt-preprocessing-file): A file of ytt data values. Applied to the template before
  processing with Cartographer.
- [Ignored Metadata Fields](#ignored-metadata-fields): Fields of the metadata that of the expected object that should
  not be tested.

### Template

The template file may be specified in the following order of precedence:

1. File named in the `.template` field of `info.yaml`
2. File named `template.yaml`
3. The template file inherited from parent directory

### Workload

The workload file may be specified in the following order of precedence:

1. File named in the `.workload` field of `info.yaml`
2. File named `workload.yaml`
3. The workload file inherited from parent directory

### Expected

The expected file may be specified in the following order of precedence:

1. File named in the `.expected` field of `info.yaml`
2. File named `expected.yaml`
3. The expected file inherited from parent directory

### Supply Chain Inputs

The inputs may be specified in the `supplyChainInputs` field of `info.yaml`. Otherwise, they are inherited from the
parent directory.

### Blueprint Params

The inputs may be specified in the `blueprintParams` field of `info.yaml`. Otherwise, they are inherited from the parent
directory.

### YTT Preprocessing File

The workload file may be specified in the `.ytt` field of `info.yaml` Otherwise, they are inherited from the parent
directory.

### Ignored Metadata Fields

- To ignore the entire metadata field, in `info.yaml` specify `ignoreMetadata: true`
- To ignore the metadata.ignoreOwnerRefs field, in `info.yaml` specify `ignoreOwnerRefs: true`
- To ignore the metadata.ignoreLabels field, in `info.yaml` specify `ignoreLabels: true`
- To ignore other metadata fields, in `info.yaml` add the field name to `ignoreMetadataFields`

## info.yaml Structure

Each folder of cartotests should contain an `info.yaml` file which can specify test metadata, behavior and inputs.

```yaml
# Name of the test
name: <string>

# Description of the test
description: <string>

# Path to the template file
template: <string>

# Path to the workload file
workload: <string>

# Path to the expected file
expected: <string>

# Path to the ytt preprocessing file
ytt: <string>

# Input values as if output from earlier steps of a supply chain
supplyChainInputs:
  sources:
    # string value should be the same as the name value
    <string>:
      name: <string>
      url: <string>
      revision: <string>
  images:
    # string value should be the same as the name value
    <string>:
      name: <string>
      image: <string>
  configs:
    # string value should be the same as the name value
    <string>:
      name: <string>
      config: <string>

# Parameters specified in a supply chain
blueprintParams:
  - # Name of the parameter.
    # Should match a template parameter name.
    name: <string>

    # Value of the parameter.
    # If specified, workload properties are ignored.
    # +optional
    value: <any>

    # DefaultValue of the parameter.
    # Causes the parameter to be optional; If the workload does not specify
    # this parameter, this value is used.
    default: <any>

# If true, only this and other focused tests will run
focus: <bool>

# If true, test comparison will ignore all fields of metadata
ignoreMetadata: <bool>

# If true, test comparison will ignore all fields of metadata.ownerRefs
ignoreOwnerRefs: <bool>

# If true, test comparison will ignore all fields of metadata.labels
ignoreLabels: <bool>

# Test comparison will ignore all named fields of metadata
ignoreMetadataFields: [<string>]
```

## How-Tos

### How to Focus Tests

The output of failing tests can get long, particularly if you have many tests. It can be helpful to focus on one or a
few tests at a time. We'll use the cartographer template tests and focus on just the kpack test. We do this by putting
`focus = true` in the `info.yaml` file.

```shell
yq '.focus = true' ./tests/templates/kpack/info.yaml -i
cartotest --directory ./tests/templates/
```

```console
PASS: tests/templates/kpack

test suite failed due to focused test, check individual test case status
FAIL
```

We only see the output for the focused test.

We also see that while the individual test passed, `cartotest` failed the test suite overall. This protects your tests
in CI, users will not get false positives if they forget to unfocus tests. Only when no test has been focused on will
`cartotest` announce an overall `PASS` and return a 0 exit code.

Let's put the files back as they were:

```shell
git checkout .
```

### How to Nest Tests and Inherit Parent State

Cartotests may be written in a nested fashion. Parent directories may declare some of the test state. Child directories
inherit this state (and may overwrite it). We can see this in action in the cartographer repo, looking at
`./tests/templates/deliverable`. That folder has the `common-workload.yaml` and `common-expectations.yaml` files. In
`info.yaml` we can see that they are set as the workload and expected file for the test. Then there are three
subfolders. Note that when the tests have been run, it has been these subfolders that were listed:

```console
PASS: tests/templates/deliverable/regular-template
PASS: tests/templates/deliverable/ytt-preprocess
PASS: tests/templates/deliverable/ytt-template
```

If a folder has a child directory, cartotest assumes that the parent folder does not contain a complete test; e.g. only
leaf directories are treated as ready to test. We can observe this behavior by creating two empty subdirectories of
`tests/templates/deliverable/regular-template` and running the tests.

```shell
mkdir tests/templates/deliverable/regular-template/some-dir
mkdir tests/templates/deliverable/regular-template/another-dir
cartotest --directory ./tests/templates/
```

```console
PASS: tests/templates/deliverable/regular-template/another-dir
PASS: tests/templates/deliverable/regular-template/some-dir
PASS: tests/templates/deliverable/ytt-preprocess
PASS: tests/templates/deliverable/ytt-template
PASS: tests/templates/kpack
PASS
```

The child (leaf) directories are tested and not the parent.

Let's set these back:

```shell
git checkout .
```

To observe inheritance of test state we can alter `tests/templates/deliverable/common-expectation.yaml` and run the
tests.

```shell
yq '.spec.source.git.url = "https://github.com/ossu/computer-science/"' ./tests/templates/deliverable/common-expectation.yaml -i
cartotest --directory ./tests/templates/
```

```console
PASS: tests/templates/kpack
FAIL: tests/templates/deliverable/regular-template
FAIL: tests/templates/deliverable/ytt-preprocess
FAIL: tests/templates/deliverable/ytt-template
FAIL
```

All of the child deliverable tests have failed. Let's make a subset of tests pass by overwriting the expectation in a
child of deliverable. We'll create a new expectation file in `./tests/templates/deliverable/regular-template` with the
proper values. Note that the filename `expected.yaml` is special and is recognized by cartotest as an expectation file.
If another filename is used, it must be declared in the `info.yaml` field `expected` (as we can see in
`tests/templates/deliverable/info.yaml`)

```shell
cp ./tests/templates/deliverable/common-expectation.yaml ./tests/templates/deliverable/regular-template/expected.yaml
yq '.spec.source.git.url = "https://github.com/vmware-tanzu/cartographer/"' ./tests/templates/deliverable/regular-template/expected.yaml -i
cartotest --directory ./tests/templates/deliverable
```

```console
PASS: tests/templates/kpack
PASS: tests/templates/deliverable/regular-template
FAIL: tests/templates/deliverable/ytt-template
FAIL: tests/templates/deliverable/ytt-preprocess
FAIL
```

The `regular-template` test now passes while the other child folders of deliverable still fail.
