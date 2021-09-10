cluster_name  = "ace-X"
cluster_nodes = {
  leaf1 = {
    user        = "terraform"
    private_key = "~/.ssh/id_rsa_terraform"
    host        = "10.64.10.133"
    roles       = ["worker"]
    labels      = ["node-role.aetherproject.org=switch"]
    taints      = ["node-role.aetherproject.org=switch:NoSchedule"]
  },
  leaf2 = {
    user        = "terraform"
    private_key = "~/.ssh/id_rsa_terraform"
    host        = "10.64.10.137"
    roles       = ["worker"]
    labels      = ["node-role.aetherproject.org=switch"]
    taints      = ["node-role.aetherproject.org=switch:NoSchedule"]
  },
  spine1 = {
    user        = "terraform"
    private_key = "~/.ssh/id_rsa_terraform"
    host        = "10.64.10.131"
    roles       = ["worker"]
    labels      = ["node-role.aetherproject.org=switch"]
    taints      = ["node-role.aetherproject.org=switch:NoSchedule"]
  },
  spine2 = {
    user        = "terraform"
    private_key = "~/.ssh/id_rsa_terraform"
    host        = "10.64.10.135"
    roles       = ["worker"]
    labels      = ["node-role.aetherproject.org=switch"]
    taints      = ["node-role.aetherproject.org=switch:NoSchedule"]
  },
  server-1 = {
    user        = "terraform"
    private_key = "~/.ssh/id_rsa_terraform"
    host        = "10.64.10.138"
    roles       = ["etcd", "controlplane", "worker"]
    labels      = []
    taints      = []
  },
  server-2 = {
    user        = "terraform"
    private_key = "~/.ssh/id_rsa_terraform"
    host        = "10.64.10.139"
    roles       = ["etcd", "controlplane", "worker"]
    labels      = []
    taints      = []
  },
  server-3 = {
    user        = "terraform"
    private_key = "~/.ssh/id_rsa_terraform"
    host        = "10.64.10.140"
    roles       = ["etcd", "controlplane", "worker"]
    labels      = []
    taints      = []
  },
  server-4 = {
    user        = "terraform"
    private_key = "~/.ssh/id_rsa_terraform"
    host        = "10.64.10.141"
    roles       = ["worker"]
    labels      = []
    taints      = []
  },
  server-5 = {
    user        = "terraform"
    private_key = "~/.ssh/id_rsa_terraform"
    host        = "10.64.10.142"
    roles       = ["worker"]
    labels      = []
    taints      = []
  }
}
cluster_labels = {
  env          = "production"
  clusterInfra = "bare-metal"
  clusterRole  = "ace"
  k8s          = "self-managed"
  coreType     = "4g"
  upfType      = "up4"
}
