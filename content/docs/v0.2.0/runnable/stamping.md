# Stamping

Cartographer refers to the process of creating an object as stamping. In stamping an object, Cartographer adds to the
metadata of the object. This metadata comes from the [two Runnable resources](runnable/architecture/#concepts) (Runnable
and ClusterRunTemplate) which define each object Runnable creates.

## Owner Reference

"In Kubernetes, some objects are owners of other objects. For example, a ReplicaSet is the owner of a set of Pods. These
owned objects are dependents of their owner." This relationship is defined in the `metadata.ownerReferences` field of
the dependent object. Read more in
[the Kubernetes documentation](https://kubernetes.io/docs/concepts/overview/working-with-objects/owners-dependents/).

When Cartographer stamps an object in Runnable, it creates an owner reference to the Runnable object. The reference will
include the following information about the Runnable:

- APIVersion
- Kind
- Name
- UID

The reference will also set:

- BlockOwnerDeletion: True
- Controller: True

Setting an owner reference has implications for garbage collection. In short, when the owner object is deleted, its
dependent object will be deleted. Read more in
[the Kubernetes documentation](https://kubernetes.io/docs/concepts/architecture/garbage-collection/#owners-dependents).

External tooling can leverage the owner reference to build logic trees of dependent objects. For examples see
[kubectl-tree](https://github.com/ahmetb/kubectl-tree) and [kube-lineage](https://github.com/tohjustin/kube-lineage).

## Labels

Runnable adds a number of labels to the objects it creates. These labels are for the internal use of Cartographer,
alteration of them will lead to unexpected behavior.

The following labels are defined on objects created by a ClusterRunTemplate and a Runnable:

- carto.run/runnable-name : The name of the runnable which produced this stamped object.
- carto.run/run-template-name : The name of the ClusterRunTemplate which produced this stamped object.
