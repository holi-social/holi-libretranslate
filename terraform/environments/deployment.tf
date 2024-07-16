/**
 * The resource ids of resources must be unique. Since we might create resources for a branch multiple times
 * (after destroying the ones created before maybe failed, e.g. on environment cleanup, reopening a branch), we ensure uniqueness
 * by appending some random data to resource ids in order to avoid collisions.
 */
resource "random_id" "main" {
  byte_length = 2
  prefix      = "libretranslate-${local.environment_name}-"
}

resource "google_project_service" "service" {
  for_each = toset([
    "run.googleapis.com",
    "servicecontrol.googleapis.com",
    "servicemanagement.googleapis.com",
  ])

  service = each.key

  project = data.terraform_remote_state.holi_infra_state.outputs.shared_project_id
  # keep this property as false. Having it true caused https://holi.atlassian.net/wiki/spaces/HOLI/pages/348258312/2023-06-27+All+services+down
  disable_dependent_services = false
  disable_on_destroy         = false
}

# in CI, this is set via scripts/create-or-update-env.sh 
variable "image_tag" {
  type     = string
  nullable = false
}

resource "google_cloud_run_v2_service" "libretranslate" {
  project  = data.terraform_remote_state.holi_infra_state.outputs.shared_project_id
  name     = random_id.main.hex
  location = local.default_region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  template {
    service_account = data.terraform_remote_state.holi_libretranslate_common_state.outputs.cloud_run_service_account_email
    containers {
      image = "libretranslate/libretranslate:latest"
      ports {
        container_port = 5000
      }
      env {
        name  = "ENVIRONMENT"
        value = local.environment
      }
      resources {
        limits = {
          cpu    = "4"
          memory = "8Gi"
        }
      }
    }

    scaling {
      min_instance_count = local.environment == "production" ? "1" : "0"
      max_instance_count = local.environment == "production" ? "10" : "3"

    }
    /*     vpc_access {
      connector = data.terraform_remote_state.holi_infra_state.outputs.vpc_access_connector_name
      egress    = "PRIVATE_RANGES_ONLY"
    } */
  }

  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }

  depends_on = [google_project_service.service]
}

resource "google_cloud_run_domain_mapping" "holi_social_libretranslate" {
  project = google_cloud_run_v2_service.libretranslate.project
  # location needs to be the same as the service's
  location = google_cloud_run_v2_service.libretranslate.location
  name     = local.dns_name

  metadata {
    namespace = google_cloud_run_v2_service.libretranslate.project
  }

  spec {
    route_name = google_cloud_run_v2_service.libretranslate.name
  }
}

# TODO security: Can we restrict this to a specific service account (of the API proxy) some day?
data "google_iam_policy" "libretranslate" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_v2_service_iam_policy" "libretranslate" {
  name        = google_cloud_run_v2_service.libretranslate.name
  location    = google_cloud_run_v2_service.libretranslate.location
  project     = google_cloud_run_v2_service.libretranslate.project
  policy_data = data.google_iam_policy.libretranslate.policy_data
}
