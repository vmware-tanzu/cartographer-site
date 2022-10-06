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

### Focusing Tests

The output of failing tests can get long, particularly if you have many tests. It can be helpful to focus on one or a
few tests at a time. Let's focus on just the kpack test. We do this by putting `focus = true` in the `info.yaml` file.

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

### Test Inheritance

Finally, let's look at how values from parent folders are shared with child tests. Cartotest allows test state to be set
in a parent folder which is then inherited by child folders. (Parent values may also be overwritten by child folders) We
can see this in action in `./tests/templates/deliverable`. That folder has the `common-workload.yaml` and
`common-expectations.yaml` files. In `info.yaml` we can see that they are set as the workload and expected file for the
test. Then there are three subfolders. Note that when the tests have been run, it has been these subfolders that were
listed:

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
