# Stamping

Cartographer refers to the process of creating an object as stamping. In stamping an object, Cartographer adds to the
metadata of the object. This metadata comes from the [three Cartographer resources](architecture/#concepts) (blueprint,
owner and template) which define each object Cartographer creates.

## Owner Reference

"In Kubernetes, some objects are owners of other objects. For example, a ReplicaSet is the owner of a set of Pods. These
owned objects are dependents of their owner." This relationship is defined in the `metadata.ownerReferences` field of
the dependent object. Read more in
[the Kubernetes documentation](https://kubernetes.io/docs/concepts/overview/working-with-objects/owners-dependents/).

When Cartographer stamps an object, it creates an owner reference to the [owner](architecture/#owners) object (the
workload or deliverable). The reference will include the following information about the owner:

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

Cartographer adds a number of labels to the objects it creates. These are convenience labels for external use.

### Workload / Supply Chain

The following labels are defined on objects created by a workload, supply chain and template:

- carto.run/workload-name : The name of the workload which produced this stamped object.
- carto.run/workload-namespace : The namespace of the owner workload. Users should expect this to be the same namespace
  as the stamped object.
- carto.run/supply-chain-name : The name of the supply chain which produced this stamped object.
- carto.run/resource-name : The name of the resource in the supply chain which produced this stamped object. (The
  [supply chain](architecture/#blueprints) has multiple named resources. Each resource points to a template).
- carto.run/cluster-template-name : The name of the template which produced this stamped object.
- carto.run/template-kind : The kind of the template which produced this stamped object (e.g. ClusterSourceTemplate).

### Deliverable / Delivery

The following labels are defined on objects created by a deliverable, delivery and template:

- carto.run/deliverable-name : The name of the deliverable which produced this stamped object.
- carto.run/deliverable-namespace : The namespace of the owner deliverable. Users should expect this to be the same
  namespace as the stamped object.
- carto.run/delivery-name : The name of the delivery which produced this stamped object.
- carto.run/resource-name : The name of the resource in the delivery which produced this stamped object. (The
  [delivery](architecture/#blueprints) has multiple named resources. Each resource points to a template).
- carto.run/template-kind : The name of the template which produced this stamped object.
- carto.run/cluster-template-name : The kind of the template which produced this stamped object (e.g.
  ClusterDeploymentTemplate).
