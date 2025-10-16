terraform {
  backend "gcs" {
    bucket = "alien-drake-474816-a2-tfstate-dev"
    prefix = "terraform/state"
  }
}
