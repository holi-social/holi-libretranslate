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

  project                    = data.terraform_remote_state.holi_infra_state.outputs.shared_project_id
  disable_dependent_services = false
  disable_on_destroy         = false
}

variable "image_tag" {
  type     = string
  nullable = false
}

resource "google_cloud_run_v2_service" "libretranslate_service" {
  project  = data.terraform_remote_state.holi_infra_state.outputs.shared_project_id
  name     = random_id.main.hex
  location = local.default_region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  template {
    service_account = data.terraform_remote_state.holi_libretranslate_common_state.outputs.cloud_run_service_account_email
    containers {
      image = "${data.terraform_remote_state.holi_infra_state.outputs.artifact_registry_location}/holi-libretranslate:${var.image_tag}"

      ports {
        container_port = 5000
      }

      env {
        name  = "ENVIRONMENT"
        value = local.environment
      }

      args = ["--host", "0.0.0.0", "--disable-web-ui"]

      resources {
        limits = {
          cpu    = local.environment == "production" ? "2" : "1"
          memory = "1536Mi"
        }
        cpu_idle          = true
        startup_cpu_boost = true
      }
    }

    scaling {
      min_instance_count = local.environment == "production" ? "1" : "0"
      max_instance_count = local.environment == "production" ? "10" : "3"
    }

    vpc_access {
      connector = "projects/${data.terraform_remote_state.holi_infra_state.outputs.shared_project_id}/locations/${local.default_region}/connectors/${data.terraform_remote_state.holi_infra_state.outputs.vpc_access_connector_name}"
      egress    = "ALL_TRAFFIC"
    }

    # labels set on the resource level
    labels = {
      "environment_type" = local.environment_type
      "holi_service"     = "libretranslate"
    }

  }

  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }

  # labels set on the service level
  labels = {
    "environment_type" = local.environment_type
    "holi_service"     = "libretranslate"
  }

  depends_on = [google_project_service.service]
}

resource "google_cloud_run_domain_mapping" "holi_social_libretranslate" {
  project  = google_cloud_run_v2_service.libretranslate_service.project
  location = google_cloud_run_v2_service.libretranslate_service.location
  name     = local.dns_name

  metadata {
    namespace = google_cloud_run_v2_service.libretranslate_service.project
  }

  spec {
    route_name = google_cloud_run_v2_service.libretranslate_service.name
  }
}

data "google_iam_policy" "libretranslate" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_v2_service_iam_policy" "libretranslate" {
  name        = google_cloud_run_v2_service.libretranslate_service.name
  location    = google_cloud_run_v2_service.libretranslate_service.location
  project     = google_cloud_run_v2_service.libretranslate_service.project
  policy_data = data.google_iam_policy.libretranslate.policy_data
}
