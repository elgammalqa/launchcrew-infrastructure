# GitHub Connection Setup for Cloud Build

## Manual Steps Required

### 1. Visit Cloud Build Console
https://console.cloud.google.com/cloud-build/triggers;region=us-central1?project=alien-drake-474816-a2

### 2. Connect GitHub Repositories

Click **"CREATE TRIGGER"** → **"CONNECT REPOSITORY"**

1. Select source: **GitHub (Cloud Build GitHub App)**
2. Click **"Continue"**
3. Authenticate with GitHub
4. Install Cloud Build app on **elgammalqa** account
5. Select repositories:
   - ✅ ai-agents-service
   - ✅ launchcrew-auth-service
   - ✅ launchcrew-billing-service
6. Click **"Connect"** for each repository
7. Click **"Done"** (don't create trigger yet)

### 3. Verify Connection

```bash
gcloud builds connections list --region=us-central1
gcloud builds repositories list --region=us-central1
```

You should see 3 repositories connected.

### 4. Enable Triggers in Terraform

Update `terraform/modules/cloudbuild/variables.tf`:
```hcl
variable "enable_triggers" {
  default = true  # Change from false to true
}
```

### 5. Apply Terraform

```bash
make -C terraform apply-dev
```

This will create 3 triggers automatically.

### 6. Verify Triggers Created

```bash
gcloud builds triggers list --region=us-central1
```

Expected output:
- ai-agents-service (triggers on dev/main)
- launchcrew-auth-service (triggers on dev/main)
- launchcrew-billing-service (triggers on dev/main)

## Troubleshooting

If you get "Repository mapping does not exist":
1. Ensure GitHub app is installed on your account
2. Ensure repositories are connected in Cloud Build console
3. Wait 1-2 minutes for connection to propagate
4. Try terraform apply again
