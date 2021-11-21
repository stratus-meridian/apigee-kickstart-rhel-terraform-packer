This repository contains the scripts and IaC code to build the Apigee Developer Portal Kickstart.

## Prerequisite
- Terraform 1.0.0 or higher
- Packer 1.7.8

## Packer and Terraform Usage

1. Clone the repository and build the image using Packer.
```
$ packer build packer.json
```

2. After successful build, go to the terraform directory.
```
$ cd terraform
```

3. Copy the [terraform.tfvars](https://console.cloud.google.com/security/secret-manager/secret/terraform-tfvars/versions?project=stratus-meridian-dev) file in Secret Manager and update the values of the variables. Use the Image ID from the packer output.

4. Initialize Terraform
```
$ terraform init
```

5. Run the Terraform plan and apply to provision the infra resources.
```
$ terraform plan -out apigee_deployment.tfplan
$ terraform apply apigee_deployment.tfplan
```

## Notes
- After provisioning of resource using Terraform, the application may be ready after a few minutes.
- If there's a redeploy to do with the VM instance that needs to be from scratch, make sure to empty the database to avoid any issue.