---
title: "Limits of Health Rules"
slug: health-rule-cron-job
date: 2022-07-27
author: Ciro Costa, Waciuma Wanjohi
authorLocation: https://github.com/vmware-tanzu/cartographer/blob/main/MAINTAINERS.md
image: /img/posts/health-rule-cron-job/cover-image.png
excerpt: "A bad time with CronJobs"
tags: ["Health Rules", "Templates"]
---

Template Authors must know the behaviors of the resources that they template and stamp out on the cluster. This includes
being able to determine if an object is healthy. Cartographer allows template authors to encode this information in
health rules, matchers on the status fields of the stamped objects. Using these rules, a workload will report whether
all objects are healthy. Template Authors may have learned about Health Rules from
[the tutorial focused on them](https://cartographer.sh/docs/v0.4.0/tutorials/determining-health/), or by reading
[the original RFC](https://github.com/vmware-tanzu/cartographer/blob/rfc-resources-report-status/rfc/rfc-0000-allow-resources-to-report-status.md)
. Today we'll discuss not what Health Rules can do, but where they fall short. There are some resources that are so far
from the norm that the conventions of Health Rules don't encompass their behavior.

Let's consider the CronJob resource. Let's create a pathological one, a cronjob that will never be healthy:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: some-ticker
spec:
  schedule: "* * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: noop
              image: busybox
              imagePullPolicy: IfNotPresent
              command: ["false"]
          restartPolicy: OnFailure
```

Unfortunately, CronJobs don't have `status.conditions` that we can rely on. If we pull the status we see:

```yaml
status:
  active:
    - apiVersion: batch/v1
      kind: Job
      name: some-ticker-27647464
      namespace: default
      resourceVersion: "28262"
      uid: 120cecd2-7cf8-4b8e-bcc2-7675750b4a53
    # ...
    - apiVersion: batch/v1
      kind: Job
      name: some-ticker-27647468
      namespace: default
      resourceVersion: "33335"
      uid: 580b9e1f-4195-4943-9583-a613cee3bac5
  lastScheduleTime: "2022-07-26T15:08:00Z"
```

There is no good indication of whether the last run succeeded or failed. In the case of success it just reports the
latest successful run:

```yaml
status:
  lastScheduleTime: "2022-07-26T15:11:00Z"
  lastSuccessfulTime: "2022-07-26T15:11:01Z" #! < shows up if we ever succeed
```

With that in mind we could perhaps write a template with a health rule like such:

```yaml
healthRule:
  multiMatch:
    healthy:
      matchFields:
        - key: "status.lastSuccessfulTime"
          operator: "Exists"
        - key: "status.lastScheduleTime"
          operator: "Exists"
    unhealthy:
      matchFields:
        - key: "status.lastScheduleTime"
          operator: "DoesNotExist"
```

But as mentioned before, it's probably not a great health rule as we'd need a single successful job run from the cronjob
to get this marked as "healthy". And the template can't determine the difference between a CronJob that's succeeded once
many years ago and one that has succeeded on the most recent attempt.

Where does this leave us? For the moment, we must understand the limits of Cartographer health rules and know that some
resources aren't great candidates for health reporting. In the long run, as use cases for including these resources in
supply chains are uncovered, they may form the basis of an RFC to enhance health rules. One could imagine a health rule
that allowed expressing the condition thatthe value found at `status.lastSuccessfulTime` must be less than the value
found at `status.lastScheduleTime`. Dear reader, perhaps you'll write that RFC!
