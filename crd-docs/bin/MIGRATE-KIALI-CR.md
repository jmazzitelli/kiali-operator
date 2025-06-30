# Kiali CR Migration Scripts

This directory contains scripts to help migrate existing Kiali Custom Resources (CRs) from the old schema to the new schema.

## Overview

Starting with Kiali Operator version 2.13, the Kiali CR schema has been reorganized to better group related Kubernetes resources. Instead of having all deployment settings in a flat structure under `spec.deployment`, related settings are now grouped into logical subsections:

- **`spec.deployment.image.*`** - Image-related settings
- **`spec.deployment.pod.*`** - Pod-related settings
- **`spec.deployment.service.*`** - Service-related settings
- **`spec.deployment.workload.*`** - Workload-related settings (replicas, HPA)
- **`spec.deployment.configmap.*`** - ConfigMap-related settings

Kiali's own observability features now have all their settings under server.observability:

- **`spec.server.observability.*`** - Observability settings (logger, profiler)

## Migration Script

### `migrate-kiali-cr.sh`

This script automatically converts existing Kiali CRs from the old schema to the new schema.

#### Prerequisites

- **`yq`** - YAML processor (required)
  - Install: https://github.com/mikefarah/yq#install
  - On RHEL/Fedora: `dnf install yq`
  - On Ubuntu/Debian: `apt install yq`
  - On macOS: `brew install yq`

#### Usage

```bash
./migrate-kiali-cr.sh -i <input-file> [-o <output-file>] [-d <true|false>] [-n <true|false>]
```

**Options:**
- `-i, --input <file>` - Input Kiali CR YAML file (required)
- `-o, --output <file>` - Output file (default: `<input>-migrated.yaml`)
- `-d, --diff <bool>` - Show diff between old and new (true|false, default: false)
- `-n, --no-backup <bool>` - Don't create backup of original file (true|false, default: false)
- `-h, --help` - Show help message

#### Examples

**Basic migration:**
```bash
./migrate-kiali-cr.sh -i my-kiali.yaml
```

**Migration with custom output and diff:**
```bash
./migrate-kiali-cr.sh -i my-kiali.yaml -o new-kiali.yaml -d true
```

**Migration without backup:**
```bash
./migrate-kiali-cr.sh -i my-kiali.yaml -n true
```

**Migration with diff enabled and backup disabled:**
```bash
./migrate-kiali-cr.sh -i my-kiali.yaml -d true -n true
```

#### Output

The script provides:
- ✅ **Backup** of original file (unless `--no-backup` is used)
- 📄 **Original YAML** display
- 🔧 **Step-by-step migration progress**
- 📄 **Migrated YAML** display
- 📊 **Diff view** (if `-d` option is used)
- 🎉 **Migration summary**

## Sample Files

- **`sample-old-kiali-cr.yaml`** - Comprehensive example with old schema
- **`simple-old-kiali-cr.yaml`** - Simple example with old schema

These files demonstrate various old schema configurations and can be used to test the migration script.

## Validation

After migration, validate the new CR against the updated CRD:

```bash
# Using the validation script
./crd-docs/bin/validate-kiali-cr.sh --kiali-cr-file <migrated-file>

# Or apply directly (if you have the CRD installed)
kubectl apply --dry-run=server -f <migrated-file>
```

## Migration Steps for Production

1. **Backup your existing Kiali CR:**
   ```bash
   kubectl get kiali <kiali-name> -n <namespace> -o yaml > kiali-backup.yaml
   ```

2. **Run the migration script:**
   ```bash
   ./migrate-kiali-cr.sh -i kiali-backup.yaml -o kiali-new.yaml -d true
   ```

3. **Review the changes:**
   - Check the diff output
   - Verify all settings are correctly migrated
   - Test in a non-production environment first

4. **Apply the migrated CR:**
   ```bash
   kubectl apply -f kiali-new.yaml
   ```

5. **Verify the deployment:**
   ```bash
   kubectl get kiali <kiali-name> -n <namespace>
   kubectl describe kiali <kiali-name> -n <namespace>
   ```

## Troubleshooting

- **`yq` not found**: Install yq as described in Prerequisites
- **Validation errors**: Some field names in your CR might not exist in the current CRD schema
- **Permission errors**: Ensure you have write permissions to the output directory
- **Backup conflicts**: Use `-n true` or move existing `.bak` files
- **Boolean parameter errors**: Ensure `-d` and `-n` options are followed by either `true` or `false`

## Support

For issues or questions:
- Check the [Kiali Documentation](https://kiali.io/docs/)
- File issues on [GitHub](https://github.com/kiali/kiali/issues)
- Join the [Kiali Community](https://kiali.io/community/)
