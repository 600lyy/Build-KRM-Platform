# Build-KRM-Platform
2022 Google Cloud Developer Day Demo: how to build a declarative infra platform with KRM


This demonstrates how to configure Config Sync to sync from multiple Git repositories. 

When you install Config Sync, you configure a root repo. After that you have the option to configure other root and namespace repos so that Config Sync can sync from multiple root and namespace repositories.

In this demo, we choose to control root and namespace repos in a central root repo, this means we keep everything in one Git repo while we create multiple RootSync and RepoSync and point each R*Sync to watch a sub-folder within the repo.

## Before you begin

1. Follow the [Parepare your lcoal enviroment](https://cloud.google.com/anthos-config-management/docs/how-to/installing-config-sync#prerequisites) to set up your GKE clusters
1. Fork this repo to you Git and grant access to Git by generating a git token

## Install Config Sync
Install and bootstrap Config Sync on your GKE clusters by runnning `install.sh`. Before that, you need to update the cluster name and zone location in the file.
Besides Config Sync, `install.sh` also generates a secret that's linked to your git token to authenticate the config sync to your Git repos

`apply-spec.yaml` includes the initial configurations that config sync will use. The installation will automatically create a RootSync syncing from the repo/dir sepcified in the `apply-spec.yaml`. 
In this example, https://github.com/600lyy/Build-KRM-Platform/cluster is the central root repo.

Should you need more RootSync, creat a RootSync object with a unique name and place the yaml spec in the central root repo. Then commit and push to the root repo:
```bash
git add .

git commit -m "create a rootsync to sync from /namespaces"

git push -u orighin main
```

## Repo Hierarchy
**Central Root Repo (`Build-KRM-Platform/cluster/`):**
```bash
├── apply-spec.yaml
├── cluster
│   └── rootsync.yaml
├── install.sh
├── namespaces
│   ├── admin.yaml
│   ├── alpha.yaml
│   └── beta.yaml
└── README.md
```

**RootSync**
RootSync let you sync cluster-scoped and namespace-scoped configs

In this demo, we create 2 RootSync
1. The RootSync that watches /cluster folder. It is created from the Config Sync installation
1. The RootSync that watches /namespaces folder. You create a RootSync object from a yaml spec and place the yaml under the /cluster folder.

**RepoSync**
RepoSync is optinal and can contain namespace-scoped configs synced to a particular namespace across you clusters.

For each namespace, we create a RepoSync to sync from a folder under /gcp-projects

## Pods
Config Sync runs on every cluster. It manages three types of Pods:
1. reconciler-manager: created during Config Sync installation
1. root/repo-reconciler: created by **reconciler-manager**. The manager watches R*Sync resources and create a reconciler pod for each one.

## RBAC/Permissions
The demo includes RoleBindings in each namespace to grant admin permission to namespace users.

For RBAC used by reconciler-manager and RootSync, see [Config Sync RBAC](https://cloud.google.com/anthos-config-management/docs/config-sync-overview#rbac_permissions)

## Validating success
**Lookup latest Git commit SHA:**
```bash
git log --color --graph
```

**Wait for config to be deployed:**
```bash
gcloud beta container hub config-management status
```

Should display "SYNCD" for all clusters with the latest commit SHA.

**Verify expected namespaces exist:**
 ```bash
 kubectl ctx $CLUSTER_NAME
 kubectl get ns
 ```

 Should include:
 - admin
 - alpha
 - beta

## Attempt to delete a namespace from the cluster
When an user attempts to delete a resource managed by Config Sync, Config Sync protects the resource from errant kubectl command.

For example, the infra-dev namespace has an annotation `configmanagement.gke.io/managed: enabled`. This annotation indicates that Config Sync is responsible for managing this resource, keeping it synced with the repo it watches.

Attempt to delete this namespace will trigger Config Sync to reconcil in the next control loop.
 ```bash
 kubectl delete namespace infra-dev
```

Expected result:
 ```bash
 kubetctl get ns infra-dev -o yaml

NAME        STATUS   AGE
alpha   Active   1s
```

You can see Config Sync re-creates the namespace on your behalf, to make sure the consistency between your current state with desired state across all clusters.

## Config Connector (KCC)