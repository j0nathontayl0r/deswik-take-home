# Platform Terraform Stack

<!-- markdownlint-disable MD013 -->

This stack manages the creation of network, vpc peering, ECS and EKS clusters, and more.

## Configuration Variables

All configuration is loaded from the file `one.yaml` by the file `_settings.tf`.

Variables can change per workspace. To access a variable in your .tf file, set it in
`one.yaml` under all workspaces and use: `local.workspace.my_variable`.

Variables that are common to all workspaces can be set at `_settings.tf`.

## Resources

- IAM Roles

## Workspaces

- prod-ap-southeast-2-default

## Deploying

### just + gum TUI workflow

The `justfile` uses `gum` to provide a TUI workspace picker for `make plan` equivalents
in `just plan` and `just select-workspace`, then runs Terraform with the selected
`WORKSPACE`.

### 1. Export Workspace

1. shared-services: `export WORKSPACE=shared-services-ap-southeast-2-default`
2. nonprod:         `export WORKSPACE=nonprod-ap-southeast-2-dev`
3. prod:            `export WORKSPACE=prod-ap-southeast-2-default`

### 2. terraform init

```shell
make init
```

### 3. terraform plan

```shell
make plan
```

### 4. terraform apply

```shell
make apply
```

### Other operations supported

Enter a shell with AWS credentials and terraform:

```shell
make shell

# common commands to run inside the shell:

# check your AWS creds by running:
aws sts get-caller-identity

# list terraform state with:
terraform state list

# import a terraform resource:
terraform import aws_guardduty_detector.member[0] 00b00fd5aecc0ab60a708659477e0627
```
