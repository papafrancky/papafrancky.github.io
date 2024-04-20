

Docs utiles :
- https://registry.terraform.io/modules/terraform-google-modules/kubernetes-engine/google/latest
- https://github.com/terraform-google-modules/terraform-google-kubernetes-engine
- https://cloud.google.com/kubernetes-engine/docs/how-to/creating-a-zonal-cluster?hl=en#terraform
- https://registry.terraform.io/modules/terraform-google-modules/kubernetes-engine/google/latest/submodules/workload-identity
- https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips?hl=en
- https://learnk8s.io/terraform-gke


resource "google_container_cluster" "default" {
  name               = "gke-standard-zonal-single-zone"
  location           = "us-central1-a"
  initial_node_count = 1

  # Set `deletion_protection` to `true` will ensure that one cannot
  # accidentally delete this instance by use of Terraform.
  deletion_protection = false
}

