# Performance Tuning

Depending on the size and characteristics of your load, the defaults for the Cartographer pod's resources may not be
sufficient. Read below to understand how the Cartographer pod uses resources, how to study your usage and tune pod
resources and concurrency parameters accordingly. Some advice specific to tuning Cartographer is given here, but it is
intended to be factored into a larger monitoring and improvement apparatus of your choosing.

## Metrics

Cartographer emits prometheus metrics. It is recommended these metrics are monitored in addition to Kubernetes pod
metrics.

## Memory consumption

The bulk of Cartographer's memory consumption has a linear relationship to the size and number of stamped objects. In
other words, it grows at the same rate as the number of owner objects and the number of resources that belong to them.

A smaller amount accounts for working memory that Cartographer uses during each reconciliation. This consumption is
spiky, and has a linear relationship to the size of templates. When Cartographer works on multiple owner objects
concurrently, then the amount of headroom required for processing these increases by the same factor as the concurrency.
This is not very pronounced at Cartographer's default concurrency level of 2, but should be kept in mind if it being
adjusted.

Ensuring Cartographer has a healthy headroom can prevent unexpected OOMKills of the Cartographer pod.

## CPU consumption

The bulk of Cartographer's CPU consumption is in parsing and templating resources as it goes about facilitating the work
of the owner object. This consumption is usually spiky, and occurs as and when owner objects require reconciliation.

To handle arbitrary quantities of owner objects, objects requiring reconciliation are queued for processing, and
Cartographer, by default, will only process 2 of each owner type (Workload, Runnable, Deliverable). With very large
numbers of objects, this can result in objects waiting in the queue for protracted periods. The following histogram
metrics can help understand queue wait times:

    ```
    workqueue_queue_duration_seconds_bucket{name="workload"}
    workqueue_queue_duration_seconds_bucket{name="runnable"}
    workqueue_queue_duration_seconds_bucket{name="deliverable"}
    ```

Increasing the concurrency can help reduce this bottleneck, but care must be taken to ensure the Pod also has the
available CPU and memory to handle this increase to avoid throttling and being OOMKilled. If CPU throttling occurs, then
the increased concurrency will have a limited impact on processing times.

## Adjusting memory and CPU resources

Memory and CPU allocation are set using
[Kubernetes standard resource requirements](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.25/#resourcerequirements-v1-core)
as part of a PodSpec's containers property in a `Deployment` of Cartographer, as might be found in one of our releases:

https://github.com/vmware-tanzu/cartographer/releases/download/v0.7.0/cartographer.yaml

## Adjusting concurrency levels

The Cartographer pod takes startup arguments which can change the concurrency levels from their default setting of 2.
These can be added to `args` for the container running `cartographer-controller` in a `Deployment` of cartographer, as
might be found in one of our releasese:

https://github.com/vmware-tanzu/cartographer/releases/download/v0.7.0/cartographer.yaml

## Example configuration customization excerpt

Here's an example extract showing the changes to adjust each of the concurrency levels for each owner object type:

    ```
    containers:
    - name: cartographer-controller
      image: projectcartographer/cartographer@sha256:<release-sha>
      args:
        - -cert-dir=/cert
        - -metrics-port=9998
        - -max-concurrent-deliveries=10     # <-- Bumped each owner type to 10
        - -max-concurrent-workloads=10      # <--
        - -max-concurrent-runnables=10      # <--
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        runAsNonRoot: true
        capabilities:
          drop:
            - all
      volumeMounts:
        - mountPath: /cert
          name: cert
          readOnly: true
      resources:
        limits:
          cpu: 3                            # <-- Bumped to 3000m max
          memory: 4Gi                       # <-- Bumped to 4Gi max
        requests:
          cpu: 1500m                        # <-- Bumped to max 1500m requests
          memory: 2Gi                       # <-- Bumped to max 2Gi requests
    ```
