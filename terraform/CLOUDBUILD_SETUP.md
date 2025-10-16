# Cloud Build Setup Instructions

## Step 1: Create GitHub Connection

Visit: https://console.cloud.google.com/cloud-build/triggers;region=us-central1/connect?project=alien-drake-474816-a2

1. Click "Connect Repository"
2. Select "GitHub (Cloud Build GitHub App)"
3. Authenticate with GitHub
4. Install the Cloud Build app on your GitHub account
5. Select repositories:
   - elgammalqa/ai-agents-service
   - elgammalqa/launchcrew-auth-service
   - elgammalqa/launchcrew-billing-service

## Step 2: Verify Connection

```bash
gcloud builds connections list --region=us-central1
gcloud builds repositories list --connection=<CONNECTION_NAME> --region=us-central1
```

## Step 3: Enable Triggers in Terraform

Update `terraform/environments/dev/main.tf`:

```hcl
module "cloudbuild" {
  source = "../../modules/cloudbuild"
  
  # ... other config ...
  enable_triggers = true  # Set to true after GitHub connection
}
```

## Step 4: Apply Terraform

```bash
make -C terraform apply-dev
```

## Verify Triggers

```bash
gcloud builds triggers list --region=us-central1
```

You should see 3 triggers:
- ai-agents-service
- launchcrew-auth-service
- launchcrew-billing-service

## Test a Build

Push to dev or main branch in any of the repos to trigger a build.

Monitor builds:
```bash
gcloud builds list --limit=5
gcloud builds log <BUILD_ID> --stream
```
