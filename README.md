# azure-poc

## Steps

1. Create new storage account with public access for the Terraform backend.

2. Create user managed indentity. Grant permissions (Contributor) on Subscription.

3. Create federeated credentials for MI.

4. Set GH worklow.

5. Grant Storage Blob Data Contribute access to storage account to MI (for least privilge).

6. St up Terragurn actions.

7. I had to add a new federated credential for environments?

# - name: Unlock
    #   uses: gruntwork-io/terragrunt-action@v3
    #   with:
    #     tg_dir: 'environments/dev/spaincentral/networking'
    #     tg_command: 'run force-unlock -- -force e24dea4c-c178-0f05-c4f2-d8301ec174a0'


IMPORTANT!!! to add the app registration to roles, search for app registration name!!! luisalbertogh-Tutorials-5fbaef3f-7f17-49ed-b299-87a7c8496743