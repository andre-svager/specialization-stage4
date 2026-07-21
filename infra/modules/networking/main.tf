# GCP networking module for ToggleMaster

resource "google_compute_network" "main" {
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"


}

resource "google_compute_subnetwork" "public" {
  count                    = length(var.availability_zones)
  name                     = "${var.environment}-public-subnet-${count.index + 1}"
  ip_cidr_range            = var.public_subnet_cidrs[count.index]
  region                   = var.region
  network                  = google_compute_network.main.id
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_subnetwork" "private" {
  count                    = length(var.availability_zones)
  name                     = "${var.environment}-private-subnet-${count.index + 1}"
  ip_cidr_range            = var.private_subnet_cidrs[count.index]
  region                   = var.region
  network                  = google_compute_network.main.id
  private_ip_google_access = true
}

resource "google_compute_router" "main" {
  name    = "${var.environment}-router"
  region  = var.region
  network = google_compute_network.main.id
}

resource "google_compute_router_nat" "main" {
  name                               = "${var.environment}-nat"
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.private[0].self_link
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.environment}-allow-ssh"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_http_https" {
  name    = "${var.environment}-allow-http-https"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
}
