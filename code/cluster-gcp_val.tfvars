cluster_name = "amp-gcp"
cluster_nodes = {
  amp-us-west2-a = {
    host        = "10.168.0.18"
    roles       = ["etcd", "controlplane", "worker"]
    labels      = []
    taints      = []
  },
  amp-us-west2-b = {
    host        = "10.168.0.17"
    roles       = ["etcd", "controlplane", "worker"]
    labels      = []
    taints      = []
  },
  amp-us-west2-c = {
    host        = "10.168.0.250"
    roles       = ["etcd", "controlplane", "worker"]
    labels      = []
    taints      = []
  }
}
cluster_labels = {
  env          = "production"
  clusterInfra = "gcp"
  clusterRole  = "amp"
  k8s          = "self-managed"
  backup       = "enabled"
}
