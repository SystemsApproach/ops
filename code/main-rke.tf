terraform {
  required_providers {
    rancher2 = {
      source  = "rancher/rancher2"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 2.1.2"
    }
  }
}

resource "rancher2_cluster" "cluster" {
  name = var.cluster_config.cluster_name

  enable_cluster_monitoring = false
  enable_cluster_alerting   = false

  labels = var.cluster_labels

  rke_config {
    kubernetes_version = var.cluster_config.k8s_version

    authentication {
      strategy = "x509"
    }

    monitoring {
      provider = "none"
    }

    network {
      plugin = "calico"
    }

    services {
      etcd {
        backup_config {
          enabled        = true
          interval_hours = 6
          retention      = 30
        }
        retention = "72h"
        snapshot  = false
      }

      kube_api {
        service_cluster_ip_range = var.cluster_config.k8s_cluster_ip_range
        extra_args = {
          feature-gates = "SCTPSupport=True"
        }
      }

      kubelet {
        cluster_domain     = var.cluster_config.cluster_domain
        cluster_dns_server = var.cluster_config.kube_dns_cluster_ip
        fail_swap_on       = false
        extra_args = {
          cpu-manager-policy = "static"
          kube-reserved      = "cpu=500m,memory=256Mi"
          system-reserved    = "cpu=500m,memory=256Mi"
          feature-gates      = "SCTPSupport=True"
        }
      }

      kube_controller {
        cluster_cidr             = var.cluster_config.k8s_pod_range
        service_cluster_ip_range = var.cluster_config.k8s_cluster_ip_range
        extra_args = {
          feature-gates = "SCTPSupport=True"
        }
      }

      scheduler {
        extra_args = {
          feature-gates = "SCTPSupport=True"
        }
      }

      kubeproxy {
        extra_args = {
          feature-gates = "SCTPSupport=True"
          proxy-mode    = "ipvs"
        }
      }
    }
    addons_include = ["https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/release-3.7/images/multus-daemonset.yml"]
    addons = var.addon_manifests
  }
}

resource "null_resource" "nodes" {
  triggers = {
    cluster_nodes = length(var.nodes)
  }

  for_each = var.nodes

  connection {
    type                = "ssh"

    bastion_host        = var.bastion_host
    bastion_private_key = file(var.bastion_private_key)
    bastion_user        = var.bastion_user

    user        = each.value.user
    host        = each.value.host
    private_key = file(each.value.private_key)
  }

  provisioner "remote-exec" {
    inline = [<<EOT
      ${rancher2_cluster.cluster.cluster_registration_token[0].node_command} \
      ${join(" ", formatlist("--%s", each.value.roles))} \
      ${join(" ", formatlist("--taints %s", each.value.taints))} \
      ${join(" ", formatlist("--label %s", each.value.labels))}
      EOT
    ]
  }
}

resource "rancher2_cluster_sync" "cluster-wait" {
  cluster_id = rancher2_cluster.cluster.id

  provisioner "local-exec" {
    command = <<EOT
      kubectl set env daemonset/calico-node \
        --server ${yamldecode(rancher2_cluster.cluster.kube_config).clusters[0].cluster.server} \
        --token ${yamldecode(rancher2_cluster.cluster.kube_config).users[0].user.token} \
        --namespace kube-system \
        IP_AUTODETECTION_METHOD=${var.cluster_config.calico_ip_detect_method}
    EOT
  }
}
