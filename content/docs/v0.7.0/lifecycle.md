# Lifecycle

Cartographer creates objects from templates and their inputs (values from user inputs or object earlier created by
Cartographer). Over the lifespan of the object, we expect the definition of the object to change due to new inputs. The
`lifecycle` field of a template allows specification of how the created object will be treated when a change is called
for. Objects are either updated or new objects are created which will be read when successful.

## Specifying No Lifecycle

If no lifecycle is specified in the template, Cartographer will default to the mutable lifecycle, described below.

## Mutable Lifecycle

For most kubernetes objects, mutable lifecycle is the proper choice. These are resources that can be updated.

```yaml
apiVersion: carto.run/v1alpha1
kind: Cluster[Config|Deployment|Image|Source]Template
spec:
  lifecycle: mutable
```

This will ensure that when a supply chain resource (step) refers to the template, the specified object will be stamped
and created in the workload's namespace. If the values passed to the template change, the object will be updated. If the
template changes the name or GVK (group, version, kind) of object being created, the new object will be created and the
previous object deleted.

{{< figure src="../img/mutable-stamp.svg" alt="Mutable Template Stamping" width="400px" >}}

The outputs from an object stamped from a mutable template are continuously read and passed on as inputs to later
resources in the supply chain.

{{< figure src="../img/mutable-read.svg" alt="Mutable Template Reading" width="400px" >}}

## Immutable Lifecycle

Some Kubernetes objects are not meant to be updated. See Jobs for an example:
https://kubernetes.io/docs/concepts/workloads/controllers/job/

> You cannot update the Job because these fields are not updatable.

Objects that are immutable should be created with the immutable lifecycle:

```yaml
apiVersion: carto.run/v1alpha1
kind: Cluster[Config|Deployment|Image|Source]Template
spec:
  lifecycle: immutable
```

When inputs to the template change and the definition of the object that would be stamped is altered, a new object will
be created on the cluster. The previous object will continue to exist.

{{< figure src="../img/immutable-stamp.svg" alt="Immutable Template Stamping" width="400px" >}}

Immutable objects are only read when their health rule is fulfilled. Implications: When no immutable objects have
previously existed and a new object is created, no values from it will be propagated down the supply chain until that
object fulfills its health rules. When multiple immutable objects exist, the most recently created healthy object will
have its values propagated down the supply chain.

{{< figure src="../img/immutable-read-1.svg" alt="Immutable Template Reading Before Healthy" width="400px" >}}

{{< figure src="../img/immutable-read-2.svg" alt="Immutable Template Reading After Healthy" width="400px" >}}

To learn about specifying health rules, see [here](./health-rules.md). A tutorial on health rules exists
[here](./tutorials/determining-health.md).

Users may specify a `retentionPolicy` to determine how many previously created objects should remain on the cluster. The
default immutable behavior is the equivalent of:

```yaml
apiVersion: carto.run/v1alpha1
kind: Cluster[Config|Deployment|Image|Source]Template
spec:
  retentionPolicy:
    maxFailedRuns: 10
    maxSuccessfulRuns: 10
```

Given an 11th healthy object, the first created object will be garbage collected, and similar behavior given an 11th
unhealthy object.

## Tekton Lifecycle

Tekton tasks and pipelines can be useful in Cartographer supply chains. The Tekton lifecycle is a convenience method
that does not need health rules specified. Given:

```yaml
apiVersion: carto.run/v1alpha1
kind: Cluster[Config|Deployment|Image|Source]Template
spec:
  lifecycle: tekton
```

immutable objects will be created on the cluster. As Tekton uses the condition `success` to indicate a healthy
pipelinerun/taskrun, Cartographer uses the equivalent of the following healthRule for tekton lifecycle objects:

```yaml
apiVersion: carto.run/v1alpha1
kind: Cluster[Config|Deployment|Image|Source]Template
spec:
  healthRule:
    singleConditionType: Success
```

Users can override the healthRule by specifying it explicitly.
