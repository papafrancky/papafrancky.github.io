terraform {
  required_version = "~> 1.5"
}
 
variable "reserved_domain_name" {
  type        = string
  description = "Your reserved domain name"
}
 
variable "application_name" {
  type        = string
  description = "Name of the contenerized application to be exposed"
  default     = "app"
}
 
data "google_client_config" "current" {}
 
resource "google_compute_global_address" "default" {
  name = var.application_name
}

resource "google_dns_managed_zone" "default" {
  name        = var.application_name
  dns_name    = "${var.application_name}.${var.reserved_domain_name}."
  description = "DNS Zone related to the application"
}

resource "google_dns_record_set" "caa" {
    name         = google_dns_managed_zone.default.dns_name
    type         = "CAA"
    ttl          = 300
    managed_zone = google_dns_managed_zone.default.application_name

    rrdatas      = [
        "0 issue \"pki.goog\"",
        "0 issue \"letsencrypt.org\""
    ]
}

resource "google_dns_record_set" "a" {
  name         = google_dns_managed_zone.default.dns_name
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.default.application_name
 
  rrdatas      = [ google_compute_global_address.default.address ]
}

resource "google_dns_record_set" "cname" {
  name         = join(".", compact(["www", google_dns_record_set.a.name]))
  type         = "CNAME"
  ttl          = 300
  managed_zone = google_dns_managed_zone.default.application_name
 
  rrdatas = [google_dns_record_set.a.name]
}
 
output "dns_zone_name_servers" {
  value       = google_dns_managed_zone.default.name_servers
  description = "IMPORTANT : replace the name servers related to your domain name with those ones on your registrar side."
}
 
output "domain" {
  value = trim(google_dns_record_set.a.name, ".")
}
