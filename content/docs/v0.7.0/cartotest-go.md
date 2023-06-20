# Cartotest Go Framework

`cartotest` is a go test framework to assert that your Cartographer templates behave as you expect.

## Quick Start

### Dependency

Users may define templates that use [ytt](https://carvel.dev/ytt/). Testing such templates requires
[installing ytt](https://carvel.dev/ytt/docs/latest/install/).

### Run

Clone the Cartographer repository:

```shell
git clone git@github.com:vmware-tanzu/cartographer.git
cd cartographer
```

Run the example template tests:

```shell
go test ./tests/templates/template_test.go -v
```

You should see

```console
=== RUN   TestTemplateExample
=== RUN   TestTemplateExample/clustertemplate_uses_ytt_field
=== RUN   TestTemplateExample/template_requires_ytt_preprocessing,_data_supplied_in_files
=== RUN   TestTemplateExample/providing_a_supply_chain_input_file
=== RUN   TestTemplateExample/template,_workload_and_expected_defined_in_files
=== RUN   TestTemplateExample/workload_defined_as_an_object
=== RUN   TestTemplateExample/expected_defined_as_an_object
=== RUN   TestTemplateExample/expected_defined_as_an_unstructured
=== RUN   TestTemplateExample/actual_supply_chain
=== RUN   TestTemplateExample/template_defined_as_an_object
=== RUN   TestTemplateExample/blueprints_defined_as_a_file
=== RUN   TestTemplateExample/template_requires_ytt_preprocessing,_data_supplied_in_object
=== RUN   TestTemplateExample/template_that_requires_a_supply_chain_input
--- PASS: TestTemplateExample (0.16s)
    --- PASS: TestTemplateExample/clustertemplate_uses_ytt_field (0.04s)
    --- PASS: TestTemplateExample/template_requires_ytt_preprocessing,_data_supplied_in_files (0.05s)
    --- PASS: TestTemplateExample/providing_a_supply_chain_input_file (0.00s)
    --- PASS: TestTemplateExample/template,_workload_and_expected_defined_in_files (0.01s)
    --- PASS: TestTemplateExample/workload_defined_as_an_object (0.00s)
    --- PASS: TestTemplateExample/expected_defined_as_an_object (0.00s)
    --- PASS: TestTemplateExample/expected_defined_as_an_unstructured (0.00s)
    --- PASS: TestTemplateExample/actual_supply_chain (0.00s)
    --- PASS: TestTemplateExample/template_defined_as_an_object (0.00s)
    --- PASS: TestTemplateExample/blueprints_defined_as_a_file (0.00s)
    --- PASS: TestTemplateExample/template_requires_ytt_preprocessing,_data_supplied_in_object (0.04s)
    --- PASS: TestTemplateExample/template_that_requires_a_supply_chain_input (0.00s)
PASS
```

Great, a passing test!

## Creating A Test

To use the cartotest framework, you'll create a `cartotesting.Suite`. The suite will map test names to
`cartotesting.Test`s. After defining the suite, call the suite's `Run` function.

`cartotesting.Test`s have 4 high level fields:

- [Given](#given): The inputs to the test
- [Expect](#expect): The object expected to be created
- [CompareOptions](#compareoptions): Methods to simplify the comparison, for example by excluding some metadata fields
- Focus: a boolean flag to focus the suite on the flagged test

### Given

Given is one of the top level fields of a [cartotest Test](#creating-a-test). The Given field must define a
[Template](#template-interface) and a [Workload](#workload-interface). They may define a
[SupplyChain](#supplychain-interface). Each of these is an interface with multiple implementations, generally allowing
provision as a go object or as a yaml file.

#### Template Interface

Template is one of the fields in [Given](#given). There are two implementations of the template interface:

- TemplateFile, which specifies the filepath of a yaml file of a Cartographer Template. It may also specify the
  [YttFiles and YttValues fields](#ytt-templating). Example: # TODO: point to example
- TemplateObject, which provides a go instance of one of the cartographer template classes. Example: # TODO: point to
  example

#### Workload Interface

Workload is one of the fields in [Given](#given). There are two implementations of the workload interface:

- WorkloadFile, which specifies the filepath of a yaml file of a Cartographer Workload. Example: # TODO: point to
  example
- WorkloadObject, which provides a go cartographer workload object. Example: # TODO: point to example

#### SupplyChain Interface

SupplyChain is one of the fields in [Given](#given). There are two implementations of the supply-chain interface:

- [SupplyChainFileSet](#supplychainfileset)
- [MockSupplyChain](#mocksupplychain)

##### SupplyChainFileSet

SupplyChainFileSet is an implementation of [SupplyChain](#supplychain-interface).

The SupplyChainFileSet allows users to specify a Supply Chain yaml file. Users specify which stage/resource in the
supply chain the test focuses on (e.g. which resource points to the template under test). Users can mock out the outputs
of earlier stages/resources that the template consumes.

Fields of SupplyChainFileSet:

- Paths: a list of filepaths. Each may be either the path of a supplychain yaml file. Or they may be a path to a
  directory containing only supplychain yaml files. Given multiple supply chains, the test will use
  [Cartographer's selector rules](architecture.md#selectors) to determine which supply chain will be paired with the
  given workload. This allows validation of the selectors on the supply chain set and the labels on the workload.
- TargetResourceName: A supplychain defines a set of resources (stages) which each point to a template. The name of the
  resource under test must be specified.
- PreviousOutputs: Previous resources in a supply chain will create outputs. This field allows users to mock these
  outputs. See an example here of creating an output and specifying it as belonging to a previous resource named
  "build-image". # TODO: link to getActualSupplyChainOutputs in example
- YttFiles: See [YTT Templating](#ytt-templating).
- YttValues: See [YTT Templating](#ytt-templating).

##### MockSupplyChain

MockSupplyChain is an implementation of [SupplyChain](#supplychain-interface).

MockSupplyChains allow mocking out the two types of values that a supply chain supplies to stamping: params and outputs
of previous resources/stages. Each of these can be specified by pointing to a yaml file, or by creating a go object.

- Inputs
  - SupplyChainInputsObject: Define an inputs object. See example #TODO
  - SupplyChainInputsFile: Provide the path of a yaml file defining inputs.
    [See example](https://github.com/vmware-tanzu/cartographer/blob/d5a9e41294a6a04b8a03298a2d96610b6d2f0343/tests/templates/kpack/inputs-file-not-used-by-cli-tests.yaml)
- Params
  - SupplyChainParamsFile: Provide the path of a yaml file defining params.
    [See example](https://github.com/vmware-tanzu/cartographer/blob/d5a9e41294a6a04b8a03298a2d96610b6d2f0343/tests/templates/deliverable/regular-template/params-file-not-used-by-cli-tests.yaml)
  - SupplyChainParamsObject: Provide a params object. To simplify this process, Cartotest provides the
    [BuildSupplyChainStringParams](# TODO) function.
    [Example usage](https://github.com/vmware-tanzu/cartographer/blob/d5a9e41294a6a04b8a03298a2d96610b6d2f0343/tests/templates/template_test.go#L34-L43)

##### Inputs vs Outputs

It is important to note that inputs and outputs are slightly different:

- [SupplyChainFileSet](#supplychainfileset) PreviousOutputs: provide the name of the previous resource that created the
  output. The supply chain spec will rename this input. Read more about that in the
  [tutorials](tutorials/extending-a-supply-chain.md#supply-chain).
- [MockSupplyChain](#mocksupplychain) Inputs: As we are mocking out the supply chain, we need not specify the previous
  resource's name. Instead we specify the name of the input as it is referred to in the template. Read more in the
  [templating documentation](templating.md#inputs)

### Expect

Expect is one of the top level fields of a [cartotest Test](#creating-a-test). This field accepts an Expectation.
Expectation is an interface with multiple implementations. This allows definition of the expected object as:

- a yaml file. Create a `cartotesting.ExpectedFile` whose `Path` field is the location of the file.
- a go object. Create a `cartotesting.ExpectedObject` whose `Object` field is the object.
- a kubernetes
  [unstructured.Unstructured](https://pkg.go.dev/k8s.io/apimachinery/pkg/apis/meta/v1/unstructured#Unstructured). Create
  a `cartotesting.ExpectedUnstructured` whose `Unstructured` field is the unstructured object.

Note on implementation: All implementations are converted into an `unstructured.Unstructured` when compared to the
object stamped by Cartographer.

### CompareOptions

CompareOptions is one of the top level fields of a [cartotest Test](#creating-a-test).

CompareOptions allows two behaviors: to ignore certain fields in the metadata of the stamped object, and to transform
the comparison function.

There are 4 fields related to ignoring the metadata:

- `IgnoreMetadata`: a boolean flag to ignore the entire metadata field
- `IgnoreOwnerRefs`: a boolean flag to ignore the ownerRefs of the stamped object
- `IgnoreLabels`: a boolean flag to ignore the labels of the stamped object
- `IgnoreMetadataFields`: a list of names of fields in the metadata that should be ignored

The `CMPOption` field accepts a function that returns
[cmp.Options](https://pkg.go.dev/github.com/google/go-cmp/cmp#Options), which can be used to change the comparison
between the expected and the actual object stamped. Cartotest provides one such function,
ConvertNumbersToFloatsDuringComparison, which coerces all numbers to be of the same type. # TODO link to function
definition.

## YTT Templating

When defining objects using a yaml file, that file may be written expecting [ytt templating](https://carvel.dev/ytt/),
including configuration from additional values specified in another file.

Values may be provided either from:

- YttFiles: a set of yaml files using the ytt `#@data/values` tag. Example: # TODO
- YttValues: a go map. Example # TODO

If the same value is provided by a YttFile and a YttValue, the YttValue will be respected. # TODO: verify
