terraform {
  required_version = "~> 1.5"
}
 
provider "google" {}
 
variable "region" {
  type        = string
  description = "Region where the cluster will be created."
  default     = "europe-west1"
}
 
variable "cluster_name" {
  type        = string
  description = "Name of the cluster"
  default     = "my-cluster"
}
 
resource "google_container_cluster" "default" {
  name             = var.cluster_name
  description      = "GKE cluster"
  location         = var.region
  enable_autopilot = true
 
  ip_allocation_policy {}
}
 
output "region" {
  value       = var.region
  description = "Compute region"
}
 
output "cluster_name" {
  value       = google_container_cluster.default.name
  description = "Cluster name"
}
