# Cartotest CLI

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

#### Dependency

Users may define templates that use [ytt](https://carvel.dev/ytt/). Testing such templates requires
[installing ytt](https://carvel.dev/ytt/docs/latest/install/).

### Run

Run the example template tests:

```shell
cartotest ./tests/templates/
```

You should see

```console
PASS: tests/templates/deliverable/regular-template
PASS: tests/templates/deliverable/ytt-preprocess
PASS: tests/templates/deliverable/ytt-template
PASS: tests/templates/deployment
PASS: tests/templates/kpack
PASS
```

Great, a passing test!

## Creating A Test

Cartotest must be supplied with a set of `given` files and an `expected` file. An `info.yaml` file can point to these
files, as well as add further configuration of the test.

### Givens

A [template](#template) yaml file and a [workload](#workload) yaml file must be specified for every test.

A supply chain may be specified, either as

- an actual [supply chain](#supply-chain) yaml file with necessary extra information in `info.yaml`; or as
- a set of [mocked supply chain](#mock-supply-chain) values specified entirely in `info.yaml`.

### Expected

An [expected](#expected) yaml file. This is the object you expect to be stamped out by Cartographer.

### CompareOptions

A [set of options](#compare-options) to alter the comparison. Specified in `info.yaml`.

## info.yaml Structure

Each folder in the directory under test should contain an `info.yaml` file which can specify test metadata, file
locations and test behavior.

```yaml
# metadata about the test
metadata:
  # Name of the test
  name: <string>
  # Description of the test
  description: <string>

# the inputs to the test
given:
  # Path to the workload file
  workload: <string>
  template:
    # Path to the template file
    path: <string>
    # Path to the ytt preprocessing file
    yttPath: <string>
  # Collection of values that the supplychain would supply for the test in question
  mockSupplyChain:
    # Input values as if output from earlier steps of a supply chain
    blueprintInputs:
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

  # An actual supplychain along with additional values that must be mocked
  supplyChain:
    # List of one or more filepaths
    # paths may be to individual supplychains, or to a directory containing only supplychains
    paths: [ ]<string>
    # Path to a ytt preprocessing file
    yttPath: <string>
    # name of the resource/stage in the supply chain that should select the template under test
    targetResourceName: <string>
    # values as if output from earlier stages of a supply chain
    previousOutputs:
      # name of a resource
      <SOME-RESOURCE-NAME>:
        image: <string>
        config: <string>
        source:
          url: <string>

# Path to the expected file
expected: <string>

# If true, only this and other focused tests will run
focus: <bool>

# Options for altering the comparison of the expected and stamped objects
compareOptions:
  # If true, test comparison will ignore all fields of metadata
  ignoreMetadata: <bool>
  # If true, test comparison will ignore all fields of metadata.ownerRefs
  ignoreOwnerRefs: <bool>
  # If true, test comparison will ignore all fields of metadata.labels
  ignoreLabels: <bool>
  # Test comparison will ignore all named fields of metadata
  ignoreMetadataFields: [ ]<string>
  # List of provided compare functions which should be applied
  namedCMPOptionFuncs:
    # Valid options:
    - ConvertNumbersToFloatsDuringComparison
```

## Reference/Inheritance

### Template

`Required`

The template file may be specified in the following order of precedence:

1. File named in the `.given.template.path` field of `info.yaml`
2. File named `template.yaml`
3. The template file inherited from parent directory

The template may be preprocessed with ytt. In that case, the data values file should be specified in the
`.given.template.yttPath` field of `info.yaml`

### Workload

`Required`

The workload file may be specified in the following order of precedence:

1. File named in the `.given.workload` field of `info.yaml`
2. File named `workload.yaml`
3. The workload file inherited from parent directory

### Expected

`Required`

The expected file may be specified in the following order of precedence:

1. File named in the `.expected` field of `info.yaml`
2. File named `expected.yaml`
3. The expected file inherited from parent directory

### Supply Chains

`Optional`

One or more supply chains may be specified. The supply chains may be specified in the following order of precedence.
These methods are exclusive, not cumulative (i.e. if supply chains are found from method 1, method 2 will not contribute
to the supply chain).

1. Files named in the `.given.supplyChain.paths` list of `info.yaml`. Paths may be to directories of files that are
   all supply chains.
2. Files with the prefix `supply-chain` and the extension `.yaml`
3. The supply chain files inherited from parent directory

If one or more supply chains are specified, a named resource must also be specified. This is the stage in the supply
chain which points to the target template. This can be specified in `info.yaml` field `.given.supplyChain.yttPath`

The supply chain may be preprocessed with ytt. In that case, the data values file should be specified in the
`.given.supplyChain.yttPath` field of `info.yaml`.

Outputs from the other resources in the supply chain may be specified in the `.given.supplyChain.previousOutputs` field
of `info.yaml`. See the [info.yaml structure](#infoyaml-structure) for the shape of these values.

Supply Chains are mutually exclusive with [mock supply chains](#mock-supply-chain). Both may not be supplied at once.

### Mock Supply Chain

`Optional`

The inputs may be specified in the `.given.mockSupplyChain` field of `info.yaml`. Otherwise, they are inherited from the
parent directory.

Mocked Supply Chains may specify a set of `inputs` (values as if previous resources in the supply chain have run) and/or
a set of `params`. See the [info.yaml structure](#infoyaml-structure) for the shape of these values.

Mock Supply Chains are mutually exclusive with [supply chains](#supply-chain). Both may not be supplied at once.

### Compare Options

`Optional`

There are several ways to exclude metadata fields from the comparison of stamped and expected objects:

- To ignore the entire metadata field, in `info.yaml` specify `compareOptions.ignoreMetadata: true`
- To ignore the metadata.ignoreOwnerRefs field, in `info.yaml` specify `compareOptions.ignoreOwnerRefs: true`
- To ignore the metadata.ignoreLabels field, in `info.yaml` specify `compareOptions.ignoreLabels: true`
- To ignore other metadata fields, in `info.yaml` add the field name to the list `compareOptions.ignoreMetadataFields`

Comparison of objects can fail on type assertion (i.e. an expected field interpreted as the int 3 and the stamped
object with the same field as the float 3). There is a named function to coerce all numbers to the type float64. To
apply this function, in `info.yaml` add the name `ConvertNumbersToFloatsDuringComparison` to the list
`compareOptions.namedCMPOptionFuncs`.

## How-Tos

### Interpreting Failing Tests

Let's make a test fail. Alter the workload so that what is stamped out by Cartographer will be different
from `expected.yaml`:

_The example edit uses mikefarah/yq for which you can find installation instructions
[here](https://github.com/mikefarah/yq#install). Alternatively you can manually change the `metadata.name` field of
`./tests/templates/kpack/workload.yaml` to `another-identifier`._

```shell
yq '.metadata.name = "another-identifier"' ./tests/templates/kpack/workload.yaml -i
```

Run cartotests again:

```shell
cartotest ./tests/templates/
```

```console
PASS: tests/templates/deliverable/regular-template
PASS: tests/templates/deliverable/ytt-preprocess
PASS: tests/templates/deliverable/ytt-template
FAIL: tests/templates/kpack
FAIL
```

We can get detail about the tests by running cartotest in verbose mode:

```shell
cartotest ./tests/templates/ -v
```

```console
DEBU[0000] populate info failed, did not find tests/templates/info.yaml

PASS: tests/templates/deliverable/regular-template
PASS: tests/templates/deliverable/ytt-preprocess
PASS: tests/templates/deliverable/ytt-template YTT Template Test
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

Let's cleanup and set the workload back to its original state:

```shell
git checkout ./tests/templates/kpack/workload.yaml
```

### How to Focus Tests

The output of failing tests can get long, particularly if you have many tests. It can be helpful to focus on one or a
few tests at a time. We'll use the cartographer template tests and focus on just the kpack test. We do this by putting
`focus = true` in the `info.yaml` file.

```shell
yq '.focus = true' ./tests/templates/kpack/info.yaml -i
cartotest ./tests/templates/
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
cartotest ./tests/templates/
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
rm -rf tests/templates/deliverable/regular-template/some-dir
rm -rf tests/templates/deliverable/regular-template/another-dir
```

To observe inheritance of test state we can alter `tests/templates/deliverable/common-expectation.yaml` and run the
tests.

```shell
yq '.spec.source.git.url = "https://github.com/ossu/computer-science/"' ./tests/templates/deliverable/common-expectation.yaml -i
cartotest ./tests/templates/
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
cartotest templates --directory ./tests/templates
```

```console
PASS: tests/templates/kpack
PASS: tests/templates/deliverable/regular-template
FAIL: tests/templates/deliverable/ytt-template
FAIL: tests/templates/deliverable/ytt-preprocess
FAIL
```

The `regular-template` test now passes while the other child folders of deliverable still fail.

Let's clean up our directory:

```shell
git checkout .
rm tests/templates/deliverable/regular-template/expected.yaml
```
