# Azure Function Source Code Deployment

Explains how the function source code is packaged, uploaded, and loaded by the
runtime as part of the Terraform/Terragrunt apply.

---

## How it works

### 1. Source code is bundled at `terraform apply` time

```
catalog/tf-modules/compute/function-src/
    function_app.py    ← Python v2 function code
    requirements.txt   ← azure-functions==1.21.3
    host.json          ← runtime config (sampling, extension bundle)
```

`data "archive_file" "hello_world"` zips that entire directory into
`.tmp/function-src.zip` **on the machine running Terraform** (the CI agent).
This happens locally — no Azure call yet.

### 2. The zip is uploaded to a blob container

```hcl
resource "azurerm_storage_blob" "function_package" {
  name                   = "function-src.zip"
  storage_account_name   = var.images_storage_account_name   # shared images account
  storage_container_name = "deploymentpackage"
  source                 = data.archive_file.hello_world.output_path
  content_md5            = data.archive_file.hello_world.output_md5
}
```

`content_md5` is key — Terraform computes the MD5 of the zip and stores it in
state. On subsequent applies, if the zip hasn't changed Terraform sees the MD5
matches and **skips the upload entirely** (no-op). If any file under
`function-src/` changes, the MD5 changes and Terraform re-uploads.

### 3. The Function App is told where its package lives

```hcl
resource "azurerm_function_app_flex_consumption" "main" {
  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "https://<storage>.blob.core.windows.net/deploymentpackage"
  storage_authentication_type = "SystemAssignedIdentity"
  ...
}
```

This tells the Flex Consumption runtime: *"your deployment package lives at this
blob container URL; use your managed identity to fetch it."*

The function app has `Storage Blob Data Owner` on the storage account, so it can
authenticate and read the zip at cold-start without any connection strings or
shared keys.

### 4. Runtime behaviour

When a function instance starts:

1. The runtime authenticates to the blob container using its **system-assigned
   managed identity** (no connection strings, no shared keys).
2. It downloads `function-src.zip` from the `deploymentpackage` container.
3. It extracts the zip, installs packages from `requirements.txt`, and starts
   the function.

---

## Deploying a code change

Push a change to any file under `catalog/tf-modules/compute/function-src/` and
run (or let the pipeline run) `terragrunt apply` on the compute unit. Terraform
repackages the zip, detects the MD5 changed, re-uploads the blob, and the
function picks up the new package on its next cold start.

```bash
cd environments/dev/spaincentral/compute
terragrunt apply
```

---

## Limitations and future improvements

The current approach **couples infrastructure and code deploys** — every code
change goes through Terraform. This is acceptable for a POC but in production
the two concerns are typically separated:

- Upload the zip independently via
  `az functionapp deployment source config-zip` in a dedicated pipeline step.
- The IaC pipeline only manages infrastructure; the code pipeline only manages
  the function package blob.

This separation allows faster code-only deploys without touching Terraform state
and avoids the risk of unintended infrastructure changes during a code rollout.
