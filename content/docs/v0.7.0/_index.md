---
version: v0.7.0
cascade:
  layout: docs
---

## TL;DR

Cartographer is a
[Supply Chain Choreographer](https://tanzu.vmware.com/developer/guides/ci-cd/supply-chain-choreography/) for Kubernetes.
It enables App Operators to create supply chains, pre-approved paths that standardize how multiple app teams deliver
applications to end users. Cartographer enables this within the Kubernetes ecosystem, allowing supply chains to be
composed of resources from an organization's existing toolchains (e.g. Jenkins).

**Each** pre-approved supply chain creates a paved road to production, orchestrating test, build, scan, deploy.
Developers are freed to focus on delivering value to their users while App Operators retain the peace of mind that all
code in production has passed through every step of an approved workflow.

## Cartographer Design and Philosophy

Cartographer allows users to define every step that an application must go through to reach production.
Users achieve this with the Supply Chain abstraction, see [Spec Reference](reference/workload#clustersupplychain).

The supply chain consists of resources that are specified via Templates. A template acts as a wrapper for a
Kubernetes resource, allowing Cartographer to integrate each well known tool into a cohesive whole. There are
four types of templates:

- [Source Template](reference/template#clustersourcetemplate)
- [Image Template](reference/template#clusterimagetemplate)
- [Config Template](reference/template#clusterconfigtemplate)
- [Generic Template](reference/template#clustertemplate)

Contrary to many other Kubernetes native workflow tools that already exist in the market, Cartographer does not “run”
any of the objects themselves. Instead, it leverages
[the controller pattern](https://kubernetes.io/docs/concepts/architecture/controller/) at the heart of Kubernetes.
Cartographer creates an object on the cluster and the controller responsible for that resource type carries out its
control loop. Cartographer monitors the outcome of this work and captures the outputs. Cartographer then applies these
outputs in the following templates in the supply chain. In this manner, a declarative chain of Kubernetes resources is
created.

The simplest explanation of Kubernetes' control loops is that an object is created with a desired state and a
controller moves the cluster closer to the desired state. For most Kubernetes objects, this pattern this includes the
ability of an actor to update the desired state (to update the spec of an object), and have the controller move the
cluster toward the new desired state. But not all Kubernetes resources are updatable; this class of immutable resources
includes resources of the CI/CD tool Tekton. Cartographer enables coordination of these resources with its
[immutable pattern](lifecycle): rather than updating an object and monitoring for its new outputs, Cartographer creates
a new immutable object and reads the outputs of the new object.

While the supply chain is operator facing, Cartographer also provides an abstraction for developers called
[workloads](reference/workload#workload). Workloads allow developers to create application specifications such as the
location of their repository, environment variables and service claims.

By design, supply chains can be reused by many workloads. This allows an operator to specify the steps in the path to
production a single time, and for developers to specify their applications independently but for each to use the same
path to production. The intent is that developers are able to focus on providing value for their users and can reach
production quickly and easily, while providing peace of mind for app operators, who are ensured that each application
has passed through the steps of the path to production that they’ve defined.

![Cartographer High Level Diagram](img/ownership-flow.png)
