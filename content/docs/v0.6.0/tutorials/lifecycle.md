# Lifecycle: Templating Objects That Cannot Update

## Overview

Most kubernetes objects are updateable. But some useful objects, like tekton taskruns, are not. Because Tekton can be
useful for creating your own actions in your supply chain, we'll explore how to use a new template field `lifecycle` to
easily create tekton taskruns.

## Environment setup

For this tutorial you will need a kubernetes cluster with Cartographer and Tekton installed. You can find
[Cartographer's installation instructions here](https://github.com/vmware-tanzu/cartographer#installation) and
[Tekton's installation instructions are here](https://github.com/pivotal/kpack/blob/main/docs/install.md).

Alternatively, you may choose to use the
[./hack/setup.sh](https://github.com/vmware-tanzu/cartographer/blob/main/hack/setup.sh) script to install a kind cluster
with Cartographer and Tekton. _This script is meant for our end-to-end testing and while we rely on it working in that
role, no user guarantees are made about the script._

Command to run from the Cartographer directory:

```shell
$ ./hack/setup.sh cluster cartographer-latest example-dependencies
```

If you later wish to tear down this generated cluster, run

```shell
$ ./hack/setup.sh teardown
```

## Scenario

Our CTO is interested in putting quality controls in place; only code that passes certain checks should be built and
deployed. They want to start small: all source code repositories that are built must pass markdown linting. In order to
do this we’re going to leverage
[the markdown linting pipeline in the TektonCD catalog](https://github.com/tektoncd/catalog/tree/main/task/markdown-lint/0.1)
.

In this tutorial we’ll see how Cartographer gives us easy updating behavior of Tekton (no need for Tekton Triggers and
Github Webhooks).

## Steps

### Tekton Basics

Before using Cartographer, let’s think about how we would use Tekton on its own to ensure a repo passes lint checks.
First we would define a pipeline:

{{< tutorial pipeline.yaml >}}

We would apply this pipeline to the cluster, along with the tasks. Those tasks are in the TektonCD Catalog:

```shell
$ kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/git-clone/0.3/git-clone.yaml
$ kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/markdown-lint/0.1/markdown-lint.yaml
```

Finally, we need to create a pipeline-run object. This object provides the param and workspace values defined at the top
level `.spec` field of the pipeline.

```yaml
---
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: linter-pipeline-run
spec:
  pipelineRef:
    name: linter-pipeline
  params:
    - name: repository
      value: https://github.com/waciumawanjohi/demo-hello-world
    - name: revision
      value: main
  workspaces:
    - name: shared-workspace
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 256Mi
```

Importantly, this pipeline-run object will kick off a single run of the pipeline. The run will either succeed or fail.
The outcome will be written into the pipeline-run’s status. No later changes to the pipeline-run object will change
those outcomes; the run happens once.

To see this in action, let’s apply the above pipeline-run. If we watch the object, we’ll soon see that it succeeds.

```shell
$ watch 'kubectl get -o yaml pipelinerun linter-pipeline-run | yq .status.conditions'
```

Eventually yields the result:

```yaml
- lastTransitionTime: ...
  message: "Tasks Completed: 2 (Failed: 0, Cancelled 0), Skipped: 0"
  reason: "Succeeded"
  status: "True"
  type: "Succeeded"
```

### Templating Pipeline Runs

Now let's do this in a supply chain. First, we'll ensure that the Tekton `tasks` and `pipeline` defined above remain
available in our namespace. Then we'll write a `ClusterSourceTemplate` to that will template out the tekton pipelinerun.
We'll ensure that the `lifecycle` field on the `ClusterSourceTemplate` is set to `tekton`. Then we'll alter a supply
chain to use our new template. And finally we'll apply a workload.

#### ClusterSourceTemplate

Let’s start by simply copying the PipelineRun above into a ClusterSourceTemplate and then look at the values that will
need to change:

```yaml
apiVersion: carto.run/v1alpha1
kind: ClusterSourceTemplate
metadata:
  name: source-linter
spec:
  template:
    apiVersion: tekton.dev/v1beta1
    kind: PipelineRun
    metadata:
      name: linter-pipeline-run # <=== Multiple objects can’t all have the same name
    spec:
      pipelineRef:
        name: linter-pipeline
      params: # <=== These param values will change
        - name: repository
          value: https://github.com/waciumawanjohi/demo-hello-world
        - name: revision
          value: main
      workspaces:
        - name: shared-workspace
          volumeClaimTemplate:
            spec:
              accessModes:
                - ReadWriteOnce
              resources:
                requests:
                  storage: 256Mi
```

Most fields are fine. The name field is not. Why not? When our inputs change, we’re not going to update the templated
object, instead we’re going to create an entirely new object. And of course that new object can’t have the same
hardcoded name. To handle this, every object templated with `lifecycle: tekton` should specify a `generateName` rather
than a `name`. We can use `linter-pipeline-run-` and kubernetes will handle putting a unique suffix on the name of each
pipeline-run.

<!-- prettier-ignore-start -->

```yaml
    metadata:
      generateName: linter-pipeline-run-
```

<!-- prettier-ignore-end -->

The other change we want to make is to the values on the params. It doesn’t do much good to hardcode
`https://github.com/waciumawanjohi/demo-hello-world` into the repository param; we want each team's repo to be templated
here.

<!-- prettier-ignore-start -->

```yaml
      params:
        - name: repository
          value: $(workload.spec.source.git.url)$
        - name: revision
          value: $(workload.spec.source.git.ref.branch)$
```

<!-- prettier-ignore-end -->

Next, let's specify the output of this template. As a `ClusterSourceTemplate` we must output a url and a revision. We
don't expect this task to mutate anything, the output value will be the same as the input value, and the output will
only be made available if the linting succeeds.

```yaml
spec:
  template: ...
  urlPath: .status.pipelineSpec.tasks[0].params[0].value
  revisionPath: .status.pipelineSpec.tasks[0].params[1].value
```

Finally, we're ready to add the lifecycle field:

```yaml
spec:
  template: ...
  urlPath: ...
  revisionPath: ...
  lifecycle: tekton
```

Let’s look at our complete template:

{{< tutorial linting-template.yaml >}}

Great! Let’s deploy this object.

#### ClusterSupplyChain

Next, let's think through where our new template will go in our supply chain. Our goal is to ensure that the only repos
that are built and deployed are those that pass linting. So we’ll need our new step to be the first step in a supply
chain. This step will receive the location of a source code and if the source code passes linting it will pass that
location information to the next step in the supply chain.

We’ll start with the supply chain we created in the Extending a Supply Chain tutorial. The resources then looked like
this:

<!-- prettier-ignore-start -->

```yaml
  resources:
    - name: build-image
      templateRef:
        kind: ClusterImageTemplate
        name: image-builder
    - name: deploy
      templateRef:
        kind: ClusterTemplate
        name: app-deploy-from-sc-image
      images:
        - resource: build-image
          name: built-image
```

<!-- prettier-ignore-end -->

We’ll add a new first step, lint source code. As we determined before, this will refer to a ClusterSourceTemplate. Our
second step will remain a ClusterImageTemplate, but it will have to be a new template. This is because it will consume
the source code from the previous step rather than directly from the workload. The rest of the resources will remain the
same.

<!-- prettier-ignore-start -->

```yaml
  resources:
    - name: lint-source
      templateRef:
        kind: ClusterSourceTemplate
        Name: source-linter
    - name: build-image
      templateRef:
        kind: ClusterImageTemplate
        name: image-builder-from-previous-step
      sources:
        - resource: lint-source
          name: source
    - name: deploy
      templateRef:
        kind: ClusterTemplate
        name: app-deploy-from-sc-image
      images:
        - resource: build-image
          name: built-image
```

<!-- prettier-ignore-end -->

Our final step with the supply chain will be referring to a service-account. Let's think through what permissions we
need:

- the `source-linter` template will create a Tekton pipelinerun.
- the `image-builder-from-previous-step` template will create a kpack image (just as the supply chain from the
  [Extending a Supply Chain](extending-a-supply-chain.md) tutorial)
- the `app-deploy-from-sc-image` template will create a deployment (just as the supply chain from the
  [Extending a Supply Chain](extending-a-supply-chain.md) tutorial)

The only new object created here is a the tekton pipelinerun. We can simply reuse the service account from the
[Extending a Supply Chain](extending-a-supply-chain.md) tutorial and add an additional role and role binding.

{{< tutorial new-role.yaml >}}

Here is our complete supply chain.

{{< tutorial supply-chain.yaml >}}

#### Templates

There is a new template that needs to be written, `image-builder-from-previous-step`. Creating this template will be
left as an exercise for the reader. Refer to the [Extending a Supply Chain tutorial](extending-a-supply-chain.md) for
help.

#### Boilerplate

Recall from the the [Extending a Supply Chain tutorial](extending-a-supply-chain.md) that there are kpack dependencies
and service accounts that are necessary for our supply chain to run properly.

### App Dev Steps

As devs, our work is easy! We submit a workload. We’re being asked for the same information as ever from the templates,
a url and a revision for the location of the source code. We can submit the same workload from the
[Extending a Supply Chain tutorial](extending-a-supply-chain.md):

{{< tutorial workload.yaml >}}

## Observe

### Stamped Object

Let’s observe the pipeline-run objects in the cluster:

```shell
$ kubectl get pipelineruns
```

We can see that a new pipelinerun has been created with the `linter-pipeline-run-` prefix:

```console
NAME                        SUCCEEDED   REASON      STARTTIME   COMPLETIONTIME
linter-pipeline-run-123az   True        Succeeded   2m48s       2m35s
```

Examining the created object it’s a non-trivial 300 lines:

```shell
$ kubectl get -o yaml pipelineruns linter-pipeline-run-123az
```

In the metadata we can see familiar labels indicating Carto objects used to create this templated object. We can also
see that the object is owned by the runnable.

```yaml
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: linter-pipeline-run-123az
  generateName: linter-pipeline-run-
  labels:
    carto.run/cluster-template-name: source-linter
    carto.run/resource-name: lint-source
    carto.run/supply-chain-name: source-code-supply-chain
    carto.run/template-kind: ClusterSourceTemplate
    carto.run/workload-name: hello-again
    carto.run/workload-namespace: default
    tekton.dev/pipeline: linter-pipeline
  ownerReferences:
    - apiVersion: carto.run/v1alpha1
      blockOwnerDeletion: true
      controller: true
      kind: Workload
      name: hello-again
      uid: ...
  ...
```

The spec contains the spec that we templated out. Looks great.

```yaml
spec:
  params:
    - name: repository
      value: https://github.com/waciumawanjohi/demo-hello-world
    - name: revision
      value: main
  pipelineRef:
    name: linter-pipeline
  serviceAccountName: default
  timeout: 1h0m0s
  workspaces:
    - name: shared-workspace
      volumeClaimTemplate:
        metadata:
          creationTimestamp: null
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 256Mi
        status: {}
```

The status contains fields expected of Tekton, including the condition indicating successful completion:

```yaml
status:
  completionTime: ...
  conditions:
    - lastTransitionTime: "2022-03-07T19:24:35Z"
      message: "Tasks Completed: 2 (Failed: 0, Cancelled 0), Skipped: 0"
      reason: Succeeded
      status: "True"
      type: Succeeded
  pipelineSpec: ...
  startTime: ...
  taskRuns: ...
```

To learn more about Tekton’s behavior, readers will want to refer to [Tekton documentation](https://tekton.dev/docs/).

### Workload and children

Using [kubectl tree](https://github.com/ahmetb/kubectl-tree) we can see our workload is parent to a pipeline-run.

```console
NAMESPACE  NAME                                                      READY  REASON        AGE
default    Workload/hello-again                                      True   Ready
default    ├─Deployment/hello-again-deployment                       -
default    │ └─ReplicaSet/hello-again-deployment-675ff9765d          -
default    │   ├─Pod/hello-again-deployment-675ff9765d-b8mfb         True
default    │   ├─Pod/hello-again-deployment-675ff9765d-h8jx5         True
default    │   └─Pod/hello-again-deployment-675ff9765d-lz4fv         True
default    ├─Image/hello-again                                       True
default    │ ├─Build/hello-again-build-1                             -
default    │ │ └─Pod/hello-again-build-1-build-pod                   False  PodCompleted
default    │ ├─PersistentVolumeClaim/hello-again-cache               -
default    │ └─SourceResolver/hello-again-source                     True
default    └─PipelineRun/linter-pipeline-run-k2n7d                   -
default      ├─PersistentVolumeClaim/pvc-48d61fa98f                  -
default      ├─TaskRun/linter-pipeline-run-k2n7d-fetch-repository    -
default      │ └─Pod/linter-pipeline-run-k2n7d-fetch-repository-pod  False  PodCompleted
default      └─TaskRun/linter-pipeline-run-k2n7d-md-lint-run         -
default        └─Pod/linter-pipeline-run-k2n7d-md-lint-run-pod       False  PodCompleted
```

We also see that the workload is in a ready state, as are all of the pods of our deployment.

### Running app

We can port-forward our app and see how it serves traffic:

```shell
$ kubectl port-forward deployment/hello-deployment 3000:80
```

We can curl our application:

```shell
curl localhost:3000
```

And the result is:

```console
I'm glad I spend Fridays with TGIK!
```

(Have you watched [the many presentations](./../../../resources/_index.md) explaining the philosophy and workings of
Cartographer?)

## Updating

### Failing a test

Let's update our workload with a new repository, this time a repository that won't pass our linting test.

{{< tutorial second-workload.yaml >}}

When we apply this to the cluster, we can observe:

- The spec of our workload is updated
- The workload causes the creation of a new pipelinerun
- The new pipeline run fails because the new repo does not pass linting

Because the pipelinerun has failed, the values passed forward through the supply chain to the next step come from the
previous pipelinerun.

If we examine the workload, we can see that the first resource is our tekton pipeline. It continues to reflect the value
of the previous pipelinerun which succeeded, rather than the more recent failed pipelinerun. With that value unchanged,
the kpack image and the deployments remain the same.

```shell
$ kubectl get -o yaml workload hello-again
```

```yaml
status:
  conditions: ...
  observedGeneration: ...
  resources:
    - conditions:
        - lastTransitionTime: "2022-11-22T16:17:04Z"
          message: ""
          reason: ResourceSubmissionComplete
          status: "True"
          type: ResourceSubmitted
        - lastTransitionTime: "2022-11-22T16:17:04Z"
          message: ""
          reason: OutputsAvailable
          status: "True"
          type: Healthy
        - lastTransitionTime: "2022-11-22T16:17:04Z"
          message: ""
          reason: Ready
          status: "True"
          type: Ready
      name: lint-source
      outputs:
        - digest: ...
          lastTransitionTime: ...
          name: url
          preview: |
            https://github.com/waciumawanjohi/demo-hello-world
        - digest: ...
          lastTransitionTime: ...
          name: revision
          preview: |
            main
      stampedRef:
        apiVersion: tekton.dev/v1beta1
        kind: PipelineRun
        name: linter-pipeline-run-abc12
        namespace: default
        resource: pipelineruns.tekton.dev
      templateRef: ...
  supplyChainRef: ...
```

Since the result of the new pipeline run is failure, no new value is passed forward to the kpack image. The deployment
remains the same. When we curl our deployment, we get the same output:

```console
I'm glad I spend Fridays with TGIK!
```

### Passing the test

Let's update the workload with new code that will pass linting:

{{< tutorial third-workload.yaml >}}

After giving the workload time to re-reconcile, we see that our curl results in a new message:

```console
It's been good talking!
```

## Wrap Up

In this tutorial you learned:

- Tekton taskruns and pipelineruns cannot be updated
- The `lifecycle: tekton` field allows you to use a template to create and recreate these immutable objects
