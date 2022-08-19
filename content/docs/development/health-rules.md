# Health Rules

Cartographer reports the health of each object stamped on the cluster. If no health rule is specified in the template,
Cartographer's health behavior will be rudimentary:

- if the object is rejected by the API server (e.g. if you mistakenly try to template out a CinfogMap instead of a
  ConfigMap) then the workload will report the resource's Healthy condition as "Unknown" for the reason
  "OutputNotAvailable". The workload will report the resource's Ready condition as "False" for the reason
  "TemplateRejectedByAPIServer".
- if the object is created but the path that is meant to be read does not exist (e.g. you have a ClusterImageTemplate
  where the imagePath mistakenly points to a non-existent field) then the workload will report the resource's Healthy
  condition as "Unknown" for the reason "OutputNotAvailable". The workload will report the resource's Ready condition as
  "Unknown" for the reason "MissingValueAtPath".

Otherwise, the object's Healthy condition will be "True". By defining one of several types of health rules, a template
author can better define the conditions that report healthy or unhealthy status. This will ensure that the proper status
is returned to users.

## Always Healthy

Some resources simply have no sense of "healthiness" and are meant to be considered always healthy. For instance, a
ConfigMap would never be unhealthy as it always simply reflects the data values that were last submitted.

Template authors may choose not specify a healthrule at all (i.e., rely on the default of being always healthy). But it
is clearer to be explicit:

```yaml
apiVersion: carto.run/v1alpha1
kind: Cluster[Config|Deployment|Image|Source]Template
spec:
  healthRule:
    alwaysHealthy: {}
```

This leads to the following status on the [owner object](architecture.md/#owners):

```yaml
status:
  conditions:
    - type: ResourcesHealthy  # <=== aggregates status.resources[*].conditions[type == Healthy].status
      status: "True"
      reason: HealthyConditionRule
    ...
  resources:
    - conditions:
        - type: Healthy
          status: "True"
          reason: AlwaysHealthy
        ...
```

## Single Condition

This type of health rule is useful for the majority of resources out there as most custom resources implement the
pattern of providing a condition set under `status.conditions`.

With `singleConditionType` all you need to provide is the type of the condition to look up when evaluating healthiness.

e.g., consider the [`kpack/Image`](https://github.com/pivotal/kpack/blob/main/docs/image.md) object:

```yaml
status:
  conditions:
    - status: "True"
      type: Ready
    - status: "True"
      type: BuilderReady
```

Given that it makes use of the `status.conditions` pattern (and `Ready: True` indicates healthiness), we can leverage
`singleConditionType`:

<!-- prettier-ignore-start -->
```yaml
  healthRule:
    singleConditionType: Ready
```
<!-- prettier-ignore-end -->

Cartographer will then consider the named condition (in this case `Ready`) and evaluate healthiness as the status on
that condition:

- healthy: status == true
- unhealthy: status == false
- unknown: anything else

The `message` field of the specified condition will be replicated on the owner object.

## Multi Match

With multiMatch we're able to specify more than one matching rule for determining healthiness. This is the most flexible
of the health rules.

For some controllers, two conditions must be met for the object to be healthy. For example in Deployments, users want
both the `Available` and `Progressing` conditions to be true. For other resources, one condition indicates the object is
healthy and another condition indicates that the object is unhealthy. Kapp's `App` resource behaves in this manner, if
the `ReconcileSucceeded` condition is true the object is healthy, while if the `ReconcileFailed` condition is true the
object is unhealthy. Multimatch can address both of these use cases.

When specifying multiMath, users must define both what constitutes healthy and what indicates unhealthy. Users may
specify multiple matchers. The matchers for healthy must all be met for an object to be healthy. If any of the matchers
under unhealthy are met, the object is considered unhealthy.

<!-- prettier-ignore-start -->
```yaml
  healthRule:
    multiMatch:
      healthy: #! matchers here are ANDed
        ...
      unhealthy: #! matchers here are ORed
        ...
```
<!-- prettier-ignore-end -->

There are two types of matchers available, matchConditions and matchFields.

### Match Conditions

MultiMatch's MatchConditions provide more nuance to SingleCondition. Users specify the `type` of the condition on the
object that should be inspected as well as the `status` value which is considered a match. When a matcher set is
satisfied, the `message` field of the first condition will be replicated on the owner object.

As an example, we can replicate the behavior of the single condition type that we observed above.

<!-- prettier-ignore-start -->
```yaml
  healthRule:
    multiMatch:
      healthy:
        - matchConditions:
            type: Ready
            status: True
      unhealthy:
        - matchConditions:
            type: Ready
            status: False
```
<!-- prettier-ignore-end -->

### Match Fields

Match fields allow users to inspect arbitrary fields on an object in order to determine health. This is useful for
objects which do not use conditions. Match fields also allow users to specify arbitrary fields on the object which
explain the reason for failure.

Using match fields we can again replicate the behavior of the single condition type that we observed above.

<!-- prettier-ignore-start -->
```yaml
  healthRule:
    multiMatch:
      healthy:
        - matchFields:
            key: 'status.conditions[?(@.type=="Ready")].status'
            operator: 'In'
            values: [ 'True' ]
            messagePath: 'status.conditions[?(@.type=="Ready")].message'
      unhealthy:
        - matchFields:
            key: 'status.conditions[?(@.type=="Ready")].status'
            operator: 'In'
            values: [ 'False' ]
            messagePath: 'status.conditions[?(@.type=="Ready")].message'
```
<!-- prettier-ignore-end -->

Along with the `In` operator, there is a `NotIn` operator that also leverages the `values` field. There are also
`Exists` and `DoesNotExist` operators.
