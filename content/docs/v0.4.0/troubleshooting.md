# Troubleshooting

## Reading your workload or deliverable status

Cartographer makes every effort to provide you with useful information in the `status` field of your `workload` or
`deliverable` object.

To see the status of your workload:

```bash
kubectl get workload <your-workload-name> -n <your-workload-namespace> -oyaml
```

**Note**: We do not recommend `kubectl describe` as it makes statuses harder to read.

Take a look at the `status:` section for conditions. E.g.:

```yaml
status:
  conditions:
    - type: SupplyChainReady
      status: True
      reason: Ready
    - type: ResourcesSubmitted
      status: True
      reason: Ready
    - type: ResourcesHealthy
      status: True
      reason: HealthyConditionRule
    - type: Ready
      status: True
      reason: Ready
```

## Common status conditions

Cartographer conditions follow the
[Kubernetes API conventions](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md#typical-status-properties)

There is a top level condition of `Type: Ready` which can have a `Status` of `Unknown`, `True` or `False`.

If your workload or deliverable's `Ready` condition has a `False` or a `Unknown` status, inspect the conditions for
cause. The `Type: Ready` condition's `Reason` will match that of the sub-condition causing the negative status.

### Sub-conditions

Aside from the top level `Ready` condition, sub-conditions provide greater detail on where things may be going wrong.

#### Sub-condition: SupplyChainReady / DeliveryReady

This condition informs whether a viable blueprint (`SupplyChain`/`Delivery`) was selected for this owner
(`Workload`/`Deliverable`). If this doesn't hold a `True` status, then the reason and message on this sub-condition will
clearly explain why not.

#### Sub-condition: ResourcesSubmitted

This condition informs whether the resources defined by the blueprint were successfully stamped and submitted to the
Kubernetes apiserver. Again, if this doesn't hold a `True` status, then the reason and message on this sub-condition
will clearly explain why not.

#### Sub-condition: ResourcesHealthy

This condition is used to inform whether the resources submitted by Cartographer are in a healthy state. This
condition's status is determined by evaluating the `healthRule` for the template used to stamp out each resource.

If this condition's status is `False` then one or more resources may not be healthy. If this condition's status is
`Unknown` then the healthy state of one or more resources cannot be determined. In such situations, consult the
individual `Healthy` condition listed in the owner's `status.resources[*].conditions`

Here's how the different `ResourceHealthy` condition statuses can come about, and what they mean:

| Status  | Reason             | What it means                                                                                                                                                                                                                       |
| ------- | ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Unknown | NoResource         | Template author specified no rule, no resource has been realized yet                                                                                                                                                                |
| True    | OutputsAvailable   | Template author specified no rule, resource created and generates valid outputs.                                                                                                                                                    |
| Unknown | OutputNotAvailable | Template author specified no rule, resource realized but no output available.                                                                                                                                                       |
| Unknown | NoStampedObject    | Template author specified no rule, resource realized but not successfully submitted yet.                                                                                                                                            |
| True    | AlwaysHealthy      | Template author specified no rule in a ClusterTemplate and resource realized and submitted.

OR

Template author specified AlwaysHealthy rule. Resource is always considered healthy.|
| Unknown | XCondition         | Template author specified SingleConditionType X, and condition X on the actual resource is not found. Message will contain this detail.                                                                                             |
| Unknown | XCondition         | Template author specified SingleConditionType X, and condition X on the actual resource is found but does not have a status of `True` or `False`. Message is copied forward from the actual resource.                               |
| False   | XCondition         | Template author specified SingleConditionType X, and condition X on the actual resource is False. Message is copied forward from the actual resource.                                                                               |
| True    | XCondition         | Template author specified SingleConditionType X, and condition X on the actual resource is True. Message is copied forward from the actual resource.                                                                                |
| False   | MatchedCondition   | Template author specified MultiMatch and a specified unhealthy matchConditions rule matched. Message contains the status and message of the matchCondition in question.                                                             |
| False   | MatchedField       | Template author specified MultiMatch and a specified unhealthy matchFields rule matched. Message contains the field value, and the result of evaluating the messagePath of the matchField in question.                              |
| True    | MatchedCondition   | Template author specified MultiMatch and all specified healthy rules matched. The first match was a matchConditions rule. Message contains the status and message of the matchCondition in question.                                |
| True    | MatchedField       | Template author specified MultiMatch and all specified healthy rules matched. The first match was a matchFields rule. Message contains the field value, and the result of evaluating the messagePath of the matchField in question. |
| Unknown | NoMatchesFulfilled | Template author specified MultiMatch but neither any unhealthy rules failed, nor all healthy rules passed.                                                                                                                          |
| Unknown | Unknown            | Unexpected, should not occur with a valid Template.                                                                                                                                                                                 |

### Unknown vs. False

A status of `False` typically means Cartographer can not proceed until user intervention occurs. These are errors in
configuration.

A status of `Unknown` indicates that resources have not yet resolved. Causes can include network timeouts, long running
processes, and occasionally a misconfiguration that Cartographer cannot itself detect.

### MissingValueAtPath

| Type               | Status             | Occurs In             |
| ------------------ | ------------------ | --------------------- |
| ResourcesSubmitted | MissingValueAtPath | Workload, Deliverable |

This is the most common `Unknown` state.

```yaml
status:
  conditions:
    - type: SupplyChainReady
      status: True
      reason: Ready
    - type: ResourcesSubmitted
      status: Unknown
      reason: MissingValueAtPath
      message:
        Waiting to read value [.status.latestImage] from resource [images.kpack.io/cool-app] in namespace [default]
    - type: Ready
      status: Unknown
      reason: MissingValueAtPath
```

You will see this as part of normal operation, because a [Blueprint Resource](architecture.md/#blueprints) is applied to
your cluster, however the [output path](architecture.md/#templates) is not populated.

If your `workload` or `deliverable` are taking a long time to become ready, then there might be an issue with the
**resource** or the **output path**

The `message:` for `ResourcesSubmitted` will help you locate the resource causing issues.

The most likely cause for this status is that the resource is unable to populate the specified path. Look at the
resource's status to diagnose the cause.

#### Resolving MissingValueAtPath when the resource is failing:

First look at the resource itself:

```bash
kubectl describe images.kpack.io/cool-app -n default
```

You will see that the value at path `.status.latestImage` is not populated. Check the status and events of the resource,
consulting the documentation for the specific resource.

#### Resolving MissingValueAtPath when the path is incorrect:

Refer to the template specified resource's documentation for the location of the required output.

For example, given the message

```
Waiting to read value [.status.latestImg] from resource [images.kpack.io/cool-app] in namespace [default]
```

- Look at the resources status, that's the most likely place you'll find the output you want

```bash
kubectl get images.kpack.io/cool-app -n default -oyaml`

...
status:
  buildCounter: 5
  conditions:
  - lastTransitionTime: "2021-11-09T03:16:54Z"
    status: "True"
    type: Ready
  - lastTransitionTime: "2021-11-09T03:16:54Z"
    status: "True"
    type: BuilderReady
  latestBuildImageGeneration: 2
  latestBuildReason: STACK
  latestBuildRef: tanzu-java-web-app-build-5
  latestImage: myrepo.io/tanzu-java-web-app@sha256:a92eafaf8a2e5ec306be44e29c9c5e0696bf2c6517b4627be1580c2d16f2ddb9
  latestStack: io.buildpacks.stacks.bionic
  observedGeneration: 2
```

- Change the **output path** of the template to match, E.g: from `.status.latestImg` to `.status.latestImage`

```yaml
apiVersion: carto.run/v1alpha1
kind: ClusterImageTemplate
metadata:
  name: kpack-template
spec:
  imagePath: .status.latestImage
```

[comment]: <> (## Viewing your supply chain or delivery instances)
