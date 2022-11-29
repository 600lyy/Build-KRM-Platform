# Build-KRM-Platform
2022 Google Cloud Developer Day Demo: how to build a declarative infra platform with KRM


This demonstrates how to configure Config Sync to sync from multiple Git repositories. 

When you install Config Sync, you configure a root repo. After that you have the option to configure other root and namespace repos so that Config Sync can sync from multiple root and namespace repositories.

In this demo, we choose to control root and namespace repos in a central root repo, this means we keep everything in one Git repo while we create multiple RootSync and RepoSync and point each R*Sync to watch a sub-folder within the repo.

## Before you begin

1. Follow the [Parepare your lcoal enviroment](https://cloud.google.com/anthos-config-management/docs/how-to/installing-config-sync#prerequisites) to set up your GKE clusters
1. Fork this repo to you Git and grant access to Git by generating a git token
1. Install gcloud, kubectrl and [kubectl ctx plugin](*https://github.com/ahmetb/kubectx#installation) 

**Note**

For existing gcloud CLI installations, make sure to set the compute/region and compute/zone properties. By setting default locations, you can avoid errors in gcloud CLI like the following: One of [--zone, --region] must be supplied: Please specify location.

## Install Config Sync
Install and bootstrap Config Sync on your GKE clusters by runnning `install.sh`. Before that, you need to update the cluster name and zone location in the file.
Besides Config Sync, `install.sh` also generates a secret that's linked to your git token to authenticate the config sync to your Git repos

`apply-spec.yaml` includes the initial configurations that config sync will use. The installation will automatically create a RootSync syncing from the repo/dir sepcified in the `apply-spec.yaml`. 
In this example, https://github.com/600lyy/Build-KRM-Platform/cluster is the central root repo.

Should you need more RootSync, creat a RootSync object with a unique name and place the yaml spec in the central root repo. Then commit and push to the root repo.

## Config Sync Concepts

**RootSync**
RootSync let you sync cluster-scoped and namespace-scoped configs

In this demo, we create 2 RootSync
1. The RootSync that watches /cluster folder. It is created from the Config Sync installation and bootstraping. You can specify a root folder in **apply.sepc.yaml**
1. The RootSync that watches /namespaces folder. We create a RootSync object from a yaml spec and place the yaml under the /cluster folder.

```bash
cp backups/rootsync.yaml cluster/

git add .
git commit -m "declar a RootSync syncing from the folder of /cluster"
git push -u orighin main
```

**RepoSync**
RepoSync is optinal and can contain namespace-scoped configs synced to a particular namespace across you clusters.

## Pods
Config Sync runs on every cluster. It manages three types of Pods:
1. reconciler-manager: created during Config Sync installation
1. root/repo-reconciler: created by **reconciler-manager**. The manager watches R*Sync resources and create a reconciler pod for each one.

## RBAC/Permissions
The demo includes RoleBindings in each namespace to grant admin permission to namespace users.

For RBAC used by reconciler-manager and RootSync, see [Config Sync RBAC](https://cloud.google.com/anthos-config-management/docs/config-sync-overview#rbac_permissions)

## Adding namespaces
Copy namespace yaml files from /backup to /namespace
```bash
cp backups/admin.yaml backups/stockholm.yaml backups/newyork.yaml namespaces
```

Git commit and push it to the remote repo
```bash
git add .
git commit -m "addning namespaces across clusters"
git push -u orighin main
```

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
 - admin (*only on the admin cluster*)
 - stockholm
 - newyork


## Config Connector (KCC)

KCC is a Kubernetes add-on that allows customers to manage GCP resources, such as CloudSQL or Cloud Storage, through KRM. See [Overview](*https://cloud.google.com/config-connector/docs/overview)

### Install KCC on the admin cluster and enable namespaced mode

```bash
 ./install-config-connector.sh

 # Enable namespaced mode
kubectl apply -f configconnector.yaml
```

### Create Googel Service Account and GKE Workload Identify in your target project

KCC is installed in one host project. When KCC operates with namespaced mode enabled, it supports mananaging mulitple projects (target projects), each with their own Goolge Service Account. See [details](*https://cloud.google.com/config-connector/docs/concepts/installation-types#namespaced)

This demo will show you how to use KCC to manage your GCP resources in the namespace "stockholm".

In pratical, you link a namespace to a gcp project. You also need to create a GSA and give it the permissions to manage resources in your target project. 

After that, you create a GKE WI that's associated with the GSA, and KCC will use the WI to manage your resource in the target project.

```bash
./setup-iam-for-kcc-ns-sthlm.sh
```

### Create a RepoSync to sync from the folder containing your gcp resource yamls

You want to spin up GCP resources in one namespace and one target project. Thus you need a RepoSync to watch over namespaced config

For each namespace, you can create a RepoSync to sync from a folder under /gcp-projects

In this demo, we create a RepoSync for the "stockholm" namespace
```bash
cp backups/reposync-stockholm.yaml cluster

git add .
git commit -m "creating a RepoSync for stockholm"
git push -u orighin main
```

** Verify the RepoSync **
```bash
kubectl ctx admin
kubectl get reposyncs.configsync.gke.io repo-sync -n stockholm -o yaml
```

should show the sourcePath
- sourcePath: /repo/source/4002dd82100320fee517d02335794fbeefb020bd/gcp-resources/stockholm

### In the root repository, declare a Kubernetes RoleBinding that grants RepoSync permissions to mange k8s objects in the namespace

Config Sync automatically creates a KSA when a new RepoSync config is synced to the cluster. See [details](*https://cloud.google.com/anthos-config-management/docs/how-to/multiple-repositories#manage-namespace-repos-in-root)
```bash
kubectl get sa -n config-management-system
```

Should display
- ns-reconciler-stockholm

This KSA will be used by the RepoSync. You need to declar a rolebinding for the KSA that grants it permission to manage objects in your target namespace
```bash
# Create a subdirectory under the root folder /cluster.
mkdir -p cluster/reposync-iam
# Make sure you update the rolebidning.yaml with the right KSA
cp backups/reposync-iam/stockholm-rolebinding.yaml cluster/reposync-iam

git add .
git commit -m "declaring rolebinding for the RepoSync stockholm"
git push -u orighin main
```

### Delcare a KCC context for your target project

To create GCP resources in your target project, you need to declare a context in KCC for each target project. 
```bash
# Make sure you update the right GSA in the configconnectorcontext.yaml
cp backups/reposync-iam/stockholm-configconnectorcontext.yaml cluster/reposync-iam

git add .
git commit -m "declaring a context in KCC for watching the namespce stockholm"
git push -u orighin main
```

Verify that KCC created a KSA for your target namespace
```bash
kubectl get serviceaccount/cnrm-controller-manager-stockholm  -n cnrm-system
```

## Spin up a GCP resource

Congrates! Now your platform is ready to support spin up gcp resources. Let's go ahead create a simple sql instance
```bash
# Make sure you update the right GSA in the configconnectorcontext.yaml
cp backups/cloudsql.yaml gcp-resources/stockholm 

git add .
git commit -m "spin up a sql instance"
git push -u orighin main
```

Verify the sql instance is creatd
```bash
gcloud sql instances list
```

### What is happening in the background?
First when you place a resource yaml in the folder that your RepoSync is syncing from, Config Sync (RepoSync) will create a kuberentes custom resources (based on cloudsql.yaml) in the admin cluster. 

KCC operator is watching over this CRD. And in the next reconciling loop, KCC will pick up this change and execute the actuation to spin up a gcp resources by calling terraform google provider.

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
stockholm   Active   1s
```

You can see Config Sync re-creates the namespace on your behalf, to make sure the consistency between your current state with desired state across all clusters.


## Troubleshooting ##
If you might encounter issues during the demo, this section describes troubleshooting techniques that you can use to troubleshoot Config Sync and KCC.

## Config Sync ##
 ```bash
 # check anthos status. All clusters should show status "SYNCED"
 gcloud beta container hub config-management status

 # check pod status of RootSync. SYNCERRORCOUNT should be blank
 kubectl get rootsyncs.configsync.gke.io -n config-management-system

 # Check the status of RepoySync. ErrorSummary shows the errors
 kubectl get reposyncs.configsync.gke.io repo-sync -n stockholm -o jsonpath='{.status.sync}'
 ```

## KCC ##
 ```bash
 # Check if KCC controller is up and running. Replace NAMESPACE
 kubectl wait -n cnrm-system \                                                                                                            
    --for=condition=Ready pod \
    -l cnrm.cloud.google.com/component=cnrm-controller-manager \
    -l cnrm.cloud.google.com/scoped-namespace=NAMESPACE

# Expected output
pod/cnrm-controller-manager-ce0dt9kgkgt2fd0ugbbg-0 condition met

# Check KCC logs. Replace NAMESPACE
kubectl logs -n cnrm-system \                
    -l cnrm.cloud.google.com/scoped-namespace=NAMESPACE \
    -l cnrm.cloud.google.com/component=cnrm-controller-manager \
    -c manager

# Check error reasons: https://cloud.google.com/config-connector/docs/troubleshooting
```

## The final Repo Hierarchy
**Central Root Repo (`Build-KRM-Platform/cluster/`):**
```bash
.
├── apply-spec.yaml
├── backups
│   ├── admin.yaml
│   ├── cloudsql.yaml
│   ├── install.sh
│   ├── newyork.yaml
│   ├── reposync-iam
│   │   ├── stockholm-configconnectorcontext.yaml
│   │   └── stockholm-rolebinding.yaml
│   ├── reposync-stockholm.yaml
│   └── stockholm.yaml
├── cluster
│   ├── reposync-iam
│   │   ├── stockholm-configconnectorcontext.yaml
│   │   └── stockholm-rolebinding.yaml
│   ├── reposync-stockholm.yaml
│   └── rootsync.yaml
├── configconnector.yaml
├── gcp-resources
│   └── stockholm
│       └── cloudsql.yaml
├── install-config-connector.sh
├── install.sh
├── namespaces
│   ├── admin.yaml
│   ├── newyork.yaml
│   └── stockholm.yaml
├── README.md
└── setup-iam-for-kcc-ns-sthlm.sh
```