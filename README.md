# azure-poc

## Steps

1. Create new storage account with public access for the Terraform backend.

2. Create user managed indentity. Grant permissions (Contributor) on Subscription.

3. Create federeated credentials for MI.

4. Set GH worklow.

5. Grant Storage Blob Data Contribute access to storage account to MI (for least privilge).

6. St up Terragurn actions.