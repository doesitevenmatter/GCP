provider "google" {
  project = var.project
  region = var.location
}

module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 3.0"

  project_id   = var.project
  network_name = "main"
  routing_mode = "REGIONAL"

  delete_default_internet_gateway_routes = "true"

  subnets = [
    {
      subnet_name           = "private"
      subnet_ip             = "10.0.1.0/24"
      subnet_region         = var.location
      subnet_private_access = "true"
      subnet_flow_logs      = "false"
    }
  ]

  routes = [
    {
      name              = "egress-internet"
      description       = "Default route through IGW to access internet"
      destination_range = "0.0.0.0/0"
      next_hop_internet = "true"
    }
  ]
}


module "cloud_router" {
  source  = "terraform-google-modules/cloud-router/google"
  version = "~> 0.4"

  name    = "router"
  project = var.project
  region  = var.location
  network = module.vpc.network_name
  nats = [{
    name                               = "nat"
    nat_ip_allocate_option             = "AUTO_ONLY"
    source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
    subnetworks = [{
      name                    = module.vpc.subnets_names[0]
      source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
    }]
  }]

    depends_on = [
    module.vpc
  ]
}

resource "google_container_cluster" "cluster" {
  name               = var.name
  initial_node_count = var.initial_node_count
  node_version       = "1.7.3"
  network            = module.vpc.network_name
  subnetwork         = module.vpc.subnets_names[0]



  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }

}