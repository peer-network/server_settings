# export.tf

resource "local_sensitive_file" "peer_network.yaml" {
  filename        = "peer_network.yaml"
  content         = yamlencode(local.peer_network)
  file_permission = "0640"
}

output "peer_network_yaml_path" {
  value = local_sensitive_file.peer_network_yaml.filename
}
