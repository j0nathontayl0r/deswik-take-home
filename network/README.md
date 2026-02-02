# Platform Terraform Stack

<!-- markdownlint-disable MD013 -->

This stack manages the creation of network, vpc peering, ECS and more.

## Configuration Variables

All configuration is loaded from the file `one.yaml` by the file `_settings.tf`.

Variables can change per workspace. To access a variable in your .tf file, set it in
`one.yaml` under all workspaces and use: `local.workspace.my_variable`.

Variables that are common to all workspaces can be set at `_settings.tf`.

## Resources

- IAM Roles

## Workspaces

- shared-services-ap-southeast-2-default
- nonprod-ap-southeast-2-dev
- prod-ap-southeast-2-default

## Deploying

### just + gum TUI workflow

The `justfile` uses `gum` to provide a TUI workspace picker for `just plan` and
`just select-workspace`, then runs Terraform with the selected `WORKSPACE`.

### 1. Export Workspace

1. prod:            `export WORKSPACE=prod-ap-southeast-2-default`

### 3. terraform init

```shell
just init
```

### 4. terraform plan

```shell
just plan
```

### 5. terraform apply

```shell
just apply
```
