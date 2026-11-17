# kube-scheduler

[English](README.md) | [简体中文](README.zh-CN.md)

A **slim extract of kube-scheduler** from [kubernetes/kubernetes](https://github.com/kubernetes/kubernetes), for reading the scheduler in isolation, call-graph analysis, or local experiments—without cloning the full Kubernetes tree.

> **Not an official Kubernetes project.** Sources are carved from the corresponding Kubernetes release tree.

## Version mapping

| This repository | Upstream Kubernetes |
|-----------------|---------------------|
| Branch `release-X.Y` | Branch `release-X.Y` |
| Tag `vX.Y.Z` | Release tag `vX.Y.Z` |

**Current tree: Kubernetes `v1.37.1` (branch `release-1.37`).**

There is no `main` / `master` default branch. Check out by release line or tag:

```bash
git clone -b release-1.37 https://github.com/autsu/kube-scheduler.git
# or pin a patch release
git checkout v1.37.1
```

When Kubernetes publishes a new release, CI attempts to sync this repo and create matching `release-*` branches and `v*` tags (see [Auto sync](#auto-sync-with-kubernetes-releases)).

## What's included

- `cmd/kube-scheduler/` — entrypoint and options
- `pkg/scheduler/` — core scheduling loop and framework plugins
- A small set of in-tree helpers (`pkg/api`, `pkg/apis`, `pkg/features`, …) required by the scheduler

Full Kubernetes is usually multi‑GB; this repo is on the order of tens of MB.

## Build & run

```bash
GOWORK=off go build -o kube-scheduler ./cmd/kube-scheduler
./kube-scheduler --help
```

Scheduling against a cluster requires a reachable kube-apiserver (e.g. `--kubeconfig`).  
The version string may show as `v0.0.0-master+...` because this slim tree does not inject official release linker metadata.

Prefer a **custom** `schedulerName` so you do not compete with the cluster's default scheduler:

```yaml
# KubeSchedulerConfiguration
profiles:
  - schedulerName: callscape-scheduler
```

```yaml
# Pod
spec:
  schedulerName: callscape-scheduler
```

## Call-graph / source reading (e.g. Callscape)

```
Project root: <path-to-this-repo>
Package pattern: ./pkg/scheduler
# or
./pkg/scheduler/...
./cmd/kube-scheduler/...
./pkg/scheduler/framework/...
```

## Auto sync with Kubernetes releases

Bundled tooling:

1. `scripts/sync-from-kubernetes.sh` — extract scheduler-related packages from a given Kubernetes tag  
2. `.github/workflows/sync-k8s-release.yml` — scheduled / manual check for new Kubernetes releases, then push matching branch + tag

Workflow outline:

1. Resolve the latest (or specified) Kubernetes release tag, e.g. `v1.38.0`  
2. Extract `cmd/kube-scheduler`, `pkg/scheduler`, and required in-tree deps  
3. Push/update branch `release-1.38` and tag `v1.38.0`

Manual sync:

```bash
./scripts/sync-from-kubernetes.sh v1.37.1
```

## Notes

- `go.mod` drops Kubernetes staging `replace` directives and uses published `k8s.io/*` modules  
- Aimed at reading, call-graph analysis, and experimentation—not a drop-in replacement for every official build/test target  
- Upstream: https://github.com/kubernetes/kubernetes

## License

Source files retain their original Kubernetes licensing (typically Apache-2.0). See upstream for details.
