resource "google_compute_instance" "bastion-b" {
  name = "${var.env}-bastion-b"
  machine_type = "g1-small"
  zone = "us-central1-b"
  tags = ["bastion", "${var.env}"]
  project = "${var.gce_project}"

  disk {
    auto_delete = true
    image = "${var.gce_bastion_image}"
    type = "pd-ssd"
  }

  network_interface {
    subnetwork = "public"
    access_config {
      # Ephemeral IP
    }
  }
}