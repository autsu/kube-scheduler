# kube-scheduler

从 [kubernetes/kubernetes](https://github.com/kubernetes/kubernetes) **源码中抽出的 kube-scheduler**，方便单独阅读、做调用图分析或本地调试，不必克隆完整 k8s 仓库。

> 本仓库**不是** Kubernetes 官方维护的镜像；代码来自对应版本的 k8s 源码树裁剪。

## 版本对应关系

| 本仓库 | 对应 Kubernetes |
|--------|-----------------|
| 分支 `release-X.Y` | k8s 分支 `release-X.Y` |
| 标签 `vX.Y.Z` | k8s 发布标签 `vX.Y.Z` |

**当前检出对应：Kubernetes `v1.37.1`（分支 `release-1.37`）**

没有 `main` / `master` 主分支；请按版本切分支/标签，例如：

```bash
git clone -b release-1.37 https://github.com/<owner>/kube-scheduler.git
# 或固定补丁版本
git checkout v1.37.1
```

新版本发布后，本仓库会通过 CI 自动尝试同步，并创建同名的 `release-*` 分支与 `v*` 标签（详见下方「自动同步」）。

## 包含内容

- `cmd/kube-scheduler/`：入口与 options
- `pkg/scheduler/`：调度核心与 framework 插件
- 少量 scheduler 直接依赖的 `pkg/api`、`pkg/apis`、`pkg/features` 等包

完整 kubernetes 通常数 GB；本仓约十几 MB 量级。

## 用 Callscape 分析

```
项目路径: <本仓库本地路径>
包范围:   ./pkg/scheduler
# 或
./pkg/scheduler/...
./cmd/kube-scheduler/...
./pkg/scheduler/framework/...
```

## 编译 / 运行

```bash
GOWORK=off go build -o kube-scheduler ./cmd/kube-scheduler
./kube-scheduler --help
```

进集群调度需要可用的 kube-apiserver（例如 `--kubeconfig`）。  
版本字符串可能显示为 `v0.0.0-master+...`，因为精简包未注入官方 release 链接信息。

建议用**自定义** `schedulerName`，避免和集群自带 default-scheduler 抢 leader：

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

## 自动同步（跟 k8s 发版）

仓库内置：

1. `scripts/sync-from-kubernetes.sh`：从指定 k8s tag 抽取 scheduler 相关包并更新工作树  
2. `.github/workflows/sync-k8s-release.yml`：定时 / 手动检查 k8s 新 release，同步后推送同名分支与 tag

工作流会：

1. 读取 kubernetes 最新（或指定）release tag，例如 `v1.38.0`  
2. 抽取 `cmd/kube-scheduler`、`pkg/scheduler` 及其 kubernetes 树内依赖包  
3. 推送/更新分支 `release-1.38`，并打标签 `v1.38.0`

也可本地手动跑：

```bash
./scripts/sync-from-kubernetes.sh v1.37.1
```

## 说明

- `go.mod` 去掉了 kubernetes staging `replace`，改用已发布的 `k8s.io/*` 模块依赖  
- 以阅读、调用图分析、二次实验为主；不保证覆盖官方全部构建/测试目标  
- Upstream：https://github.com/kubernetes/kubernetes
