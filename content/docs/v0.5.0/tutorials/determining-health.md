# Determining Health

## Overview

In this tutorial we’ll explore how to use health rules to let users know if their supply chain is working correctly.
We’ll see how the different types of resources you create in a supply chain effects what health rules are appropriate.

## Environment setup

For this tutorial you will need a kubernetes cluster with Cartographer installed. You may follow
[the installation instructions here](https://github.com/vmware-tanzu/cartographer#installation).

Alternatively, you may choose to use the
[./hack/setup.sh](https://github.com/vmware-tanzu/cartographer/blob/main/hack/setup.sh) script to install a kind cluster
with Cartographer. _This script is meant for our end-to-end testing and while we rely on it working in that role, no
user guarantees are made about the script._

Command to run from the Cartographer directory:

```shell
$ ./hack/setup.sh cluster cartographer-latest
```

If you later wish to tear down this generated cluster, run

```shell
$ ./hack/setup.sh teardown
```

## Personas

In previous tutorials, we've split the personas between app operator and app developer. Now we will split the personas
between authors and users.

### Template Author

A template author is the expert on some kubernetes resource (e.g. Pods, kpack Images, Knative Services). They understand
the behavior of the resource and the fields in the resource's spec and status. It is their responsibility to write a
Cartographer template that wraps their resource.

### Supply Chain Author

A supply chain author is the organization's expert on organizational policy. They know what steps must happen to take
source code and verify that it is ready for deployment on a cluster. (There are no special steps for supply chain
authors in this tutorial, but they are mentioned for completeness)

### User

A user will be any persona that is interested in what happens when a workload is applied to the cluster. Often this is
the app developer persona, who has created a workload and wants to know that their code has reached production. This can
also be the app operator persona, who knows that some devs have workloads and wants to know that changes are smoothly
reaching production.

## Scenario

At the Hello World Application Inc., we've observed that not all workloads are providing valid configuration, leading to
supply chains that cannot stamp out k8s deployments. We want to make sure that in this case, the workload object
reflects the problem. We will add health rules to the template that we created in
["Build Your First Supply Chain"](first-supply-chain.md).

## Steps

### Template Author Steps

Previously, we created a Supply Chain with just one step: it creates a deployment. As template authors it is our
responsibility to be experts on the resource we template out. Let's review just a few details that will be important to
remember about kubernetes deployments:

- A deployment creates a replicaset, which in turn creates pods.
- A deployment status has conditions. [Read more on k8s conditions](https://maelvls.dev/kubernetes-conditions/).
- The deployment condition "Available" reports whether the declared number of pod replicas are available on the cluster.
- The deployment condition "Progressing" reports whether the managed replicasets are making progress in creating pods.
- The progressing condition will change from True to False if the timeout set in the deployment's
  `spec.progressDeadlineSeconds` field is exceeded.

For a more thorough review of Deployments, see the
[kubernetes documentation](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/).

We'll start by setting a progress deadline. We'll set a timeout of 30 seconds because this is a demo (we're not
suggesting this is the appropriate value for the real world). In the `template` field of our cluster template we see our
deployment. There we can see the new `spec.progressDeadlineSeconds` field.

```yaml
apiVersion: carto.run/v1alpha1
kind: ClusterTemplate
metadata:
  name: app-deploy
spec:
  template:
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: $(workload.metadata.name)$-deployment
      labels:
        app: $(workload.metadata.name)$
    spec:
      progressDeadlineSeconds: 30 # <=== NEW CONFIG
      replicas: 3
      selector:
        matchLabels:
          app: $(workload.metadata.name)$
      template:
        metadata:
          labels:
            app: $(workload.metadata.name)$
        spec:
          containers:
            - name: $(workload.metadata.name)$
              image: $(workload.spec.image)$
```

Next we'll write our health rule. When the workload reports the health of the deployment we'll report if healthy is "
True", "False", or "Unknown". Deployments have two conditions, progressing and available that report "True" or "False".
Let's consider how we'll want to represent each of these states:

| Available | Progressing | Workload Reports Healthy as: | Reason                                                                                                |
| --------- | ----------- | ---------------------------- | ----------------------------------------------------------------------------------------------------- |
| True      | True        | True                         | Pods are all available and any updates necessary are progressing properly                             |
| True      | False       | False                        | There are pods available, but the necessary updates (changes our workload expects) aren't progressing |
| False     | True        | Unknown                      | The expected pods are not available, but work is progressing and may resolve                          |
| False     | False       | False                        | The expected pods are not available, and necessary updates aren't progressing                         |

From this we know that Workload should report the Deployment as Healthy when both available and progressing are true. It
should report False whenever progressing is False. And report unknown otherwise. With this in mind, we're ready to write
our healthrule.

Because health of a Deployment depends on more than one condition, we'll write a multimatch health rule. A multimatch
rule requires that we define what constitutes both healthy and unhealthy. (Good thing we just determined that above!)
For both healthy and unhealthy we'll specify a set of matchers. If _all_ the healthy matchers are satisfied, we'll
report healthy == True. If _any_ of the unhealthy matchers are satisfied, we'll report healthy == False. Otherwise,
we'll report healthy == Unknown.

```yaml
apiVersion: carto.run/v1alpha1
kind: ClusterTemplate
spec:
  ...
  healthRule:
    multiMatch:
      healthy:    # Matchers are ANDed
      unhealthy:  # Matchers are ORed
```

_Note: Health rules are available on all Carto templates (e.g. ClusterSourceTemplate, ClusterImageTemplate, etc)._

Let's begin with the healthy matchers. Two different conditions on a Deployment must be true for it to be healthy. We
can write these as `matchConditions`. We just need to provide the conditions' `type` and `status`.

<!-- prettier-ignore-start -->
```yaml
      healthy:
        matchConditions:
          - type: Available
            status: 'True'
          - type: Progressing
            status: 'True'
```
<!-- prettier-ignore-end -->

And we can write the unhealthy matcher:

<!-- prettier-ignore-start -->
```yaml
      unhealthy:
        matchConditions:
          - type: Progressing
            status: 'False'
```
<!-- prettier-ignore-end -->

Let's bring this all together and look at the template we'll apply to the cluster:

{{< tutorial app-deploy-template.yaml >}}

Otherwise we'll apply the same app operator objects (supply chain, service account, role, role binding) from the
["Build Your First Supply Chain"](first-supply-chain.md) tutorial.

### App Dev Steps

Let's apply a workload that we know will succeed, as we've used it before:

{{< tutorial workload.yaml >}}

## Observe

We've seen this workload and supply chain before, so we know what objects will be created (a deployment, which will
create a replicaset, which will create pods). What is different in this tutorial is the status of the workload itself.

Let's observe the workload after giving a moment for the deployment's pods to come up.

```shell
kubectl get -o yaml workload hello
```

First let's consider the `status.resources` field:

```yaml
status:
  ...
  resources:
      - name: deploy
        conditions:
          - type: ResourceSubmitted
            status: "True"
            reason: ResourceSubmissionComplete
          - type: Healthy
            status: True
            reason: MatchedCondition
            message: 'condition status: True, message: Deployment has minimum availability.'
          - reason: Ready
            status: Unknown
            type: Ready
```

Look at that second condition! Healthy is true. Our matchers were satisfied. Great stuff.

Next let's look at the top level conditions of the workload and concentrate on the condition with type
`ResourcesHealthy`:

```yaml
status:
  conditions:
    - reason: HealthyConditionRule
      status: True
      type: ResourcesHealthy
```

This condition on the workload aggregates the health of all the objects created by the workload. If all are healthy, the
condition is true. If any are unhealthy, the condition is False. Otherwise the condition is Unknown. In our case, the
aggregation is trivial to compute; the workload's `ResourcesHealthy` condition is true.

## Steps of an unfortunate dev

At some point, each of us will make a mistake, like mistyping the name of an image in our workload. Let's try submitting
the following workload:

{{< tutorial workload-2.yaml >}}

We'll see what feedback we get in the workload status.

### Observe

First, we'll check the workload just after deploying, inspecting the `status.resources`:

```shell
kubectl get -o yaml workload typo
```

```yaml
status:
  resources:
    - conditions:
        - type: ResourceSubmitted
          status: "True"
          reason: ResourceSubmissionComplete
        - type: Healthy
          status: Unknown
          reason: NoMatchesFulfilled
        - type: Ready
          status: Unknown
          reason: NoMatchesFulfilled
```

From our discussion above, we know that the deployment will never reach a healthy state, but until it hits the timeout
it will continue to report that it is progressing but the expected pods are not available. We can observe this directly:

```shell
kubectl get -o yaml deployment typo-deployment
```

```yaml
apiVersion: apps/v1
kind: Deployment
status:
  conditions:
    - message: Deployment does not have minimum availability.
      reason: MinimumReplicasUnavailable
      status: "False"
      type: Available
      ...
    - message: ReplicaSet "hello-deployment-SOMEHASH" is progressing.
      reason: ReplicaSetUpdated
      status: "True"
      type: Progressing
      ...
```

Let's check back in on the deployment status after 30 seconds:

<!-- prettier-ignore-start -->
```yaml
  - message: Deployment does not have minimum availability.
    reason: MinimumReplicasUnavailable
    status: "False"
    type: Available
  - message: ReplicaSet "typo-deployment-SOMEHASH" has timed out progressing.
    reason: ProgressDeadlineExceeded
    status: "False"
    type: Progressing
```
<!-- prettier-ignore-end -->

We see that the Progressing condition has switched to `False`.

Let's verify that our workload healthy condition is reflecting this. We'll observe `status.resources`

```yaml
status:
  resources:
    - conditions:
      ...
      - type: Healthy
        status: "False"
        message: 'condition status: False, message: ReplicaSet "typo-deployment-7b8bd888d8"
        has timed out progressing.'
        reason: MatchedCondition
```

We see that `status.resources` reports that an unhealthy condition matcher was satisfied. The `message` of that
condition on the deployment is reflected in the workload's status.resources[x].conditions[x].message field.

And we cn observe that the workload's top level conditions then mirror this message in the `ResourcesHealthy` condition:

```yaml
status:
  conditions:
  ...
  - type: ResourcesHealthy
    status: "False"
    message: 'condition status: False, message: ReplicaSet "typo-deployment-7b8bd888d8"
      has timed out progressing.'
    reason: HealthyConditionRule
```

## Wrap Up

Congratulations, you’ve used a healthrule to make your supply chain more understandable and repairable! You’ve learned:

- How to specify a multimatch rule with matchConditions matchers
- How to read the workload's `status.resources` `healthy` conditions
- How to read the workload's `ResourcesHealthy` condition

To learn more, read the
[troubleshooting guide on ResourcesHealthy](../troubleshooting.md#sub-condition-resourceshealthy). It explores the
possible values you'll see and their meanings.

Also check out the [reference page for the template CRDs](../reference/template.md)

And read [this blog post](https://cartographer.sh/posts/health-rule-cron-job/) on an example resource for which
determining a health rule is currently not possible!
