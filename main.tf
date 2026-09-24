provider "google" {
  project = "project-10094705-9153-43d5-bb8"
  region  = "asia-south1"
}

# 1. Artifact Registry
resource "google_artifact_registry_repository" "my_app_repo" {
  location      = "asia-south1"
  repository_id = "my-app-repo"
  format        = "DOCKER"
}

# 2. GKE Cluster with Workload Identity ENABLED
resource "google_container_cluster" "primary" {
  name     = "jenkins-cluster"
  location = "asia-south1-a"
  initial_node_count = 2
  deletion_protection = false
  
  workload_identity_config {
    workload_pool = "project-10094705-9153-43d5-bb8.svc.id.goog"
  }
  
  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 30
    # Don't use compute SA with Owner. Use default with minimal scope.
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

# 3. GSA for Jenkins - Least Privilege, NOT Owner
resource "google_service_account" "jenkins_gsa" {
  account_id   = "jenkins-workload-sa"
  display_name = "Jenkins Workload Identity SA"
}

resource "google_project_iam_member" "jenkins_artifact_writer" {
  project = "project-10094705-9153-43d5-bb8"
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.jenkins_gsa.email}"
}

resource "google_project_iam_member" "jenkins_k8s_deployer" {
  project = "project-10094705-9153-43d5-bb8"
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.jenkins_gsa.email}"
}

resource "google_project_iam_member" "jenkins_storage_admin" {
  project = "project-10094705-9153-43d5-bb8"
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.jenkins_gsa.email}"
}

# 4. Allow KSA to impersonate GSA - This is the WI link
resource "google_service_account_iam_member" "wi_binding" {
  service_account_id = google_service_account.jenkins_gsa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:project-10094705-9153-43d5-bb8.svc.id.goog[jenkins/jenkins-ksa]"
}

output "registry_url" {
  value = "${google_artifact_registry_repository.my_app_repo.location}-docker.pkg.dev/${google_artifact_registry_repository.my_app_repo.project}/${google_artifact_registry_repository.my_app_repo.name}"
}