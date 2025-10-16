terraform {
  backend "gcs" {
    bucket = "REPLACE_WITH_YOUR_BUCKET_NAME-tfstate-prod"
    prefix = "terraform/state"
  }
}
