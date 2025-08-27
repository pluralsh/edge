# Edge

Get Plural running on your edge devices with either:

1. A Kairos-based immutable OS image you flash (recommended for greenfield)
2. An existing Linux installation (Debian/Ubuntu/Alpine/etc.) you bootstrap in-place with the provided script

---
## At a Glance

| Scenario | Use This | You Get |
|----------|----------|---------|
| Fresh device, want managed immutable OS | `plural edge image` + flash | Kairos image with k3s + bundles auto-connecting to Console |
| Existing Linux box (no Kairos) | `hack/k3s/bootstrap.sh` | Installs k3s, loads air‑gapped images, registers with Console |
| Air‑gapped / bandwidth constrained | Pre-run `bootstrap.sh --download-assets` elsewhere, copy assets, then bootstrap | No large downloads on device |

---
## Prerequisites

General:
- Edge device (tested on Raspberry Pi 4 8GB; script is arch‑agnostic if you supply matching bundles)
- A running management cluster hosting Plural Console & operators
- A Plural bootstrap token (limited scope: only initial registration) and the Console URL

For Kairos image path:
- Workstation with Plural CLI installed (see [quickstart](https://docs.plural.sh/deployments/cli-quickstart))
- SD card / storage ≥ 16GB

For bootstrap (non‑Kairos) path:
- Existing Linux OS with root or passwordless sudo
- cgroups v1 or v2 enabled (script validates)
- iptables available
- Disk space: ≥ 1GB free in /var/lib (more recommended)
- Docker to download assets directly on the device and run K3s Kubernetes cluster

---
## Bundles Overview

The following OCI bundle images provide assets (manifests and pre-pulled images) consumed by both workflows:

- `kairos-plural-bundle` – core manifests that launch a job connecting the device to Plural Console
- `kairos-plural-images-bundle` – preloaded container images to speed up first start (optional but recommended for slow links)
- `kairos-plural-trust-manager-bundle` – cert-manager + trust-manager (optional)
- `k3s-bundle` – k3s binary + airgap images (used only by bootstrap path)

Kairos workflow injects these bundles via `cloud-config.yaml`; bootstrap script vendors them locally then installs.

---
## Option 1: Kairos Image (Flash Workflow)

This produces a Kairos image with everything embedded. From repo root (or the `edge/` folder):

```bash
plural edge image            # builds (or downloads) the Kairos image using plural-config.yaml
sudo plural edge flash       # flashes image to selected block device (interactive)
```

To check for available options:
```bash
plural edge image -h
plural edge flash -h
```

During first boot Kairos:
1. Applies `cloud-config.yaml`
2. Loads the declared bundles (local tarballs) 
3. Writes `/etc/plural-id` (unique UUID)
4. Starts k3s with embedded registry and disabled Traefik/ServiceLB
5. Runs the Plural job which registers the device with your Console using templated `@TOKEN@` and `@URL@`

Placeholders replaced automatically by the CLI when building the image:
- `@USERNAME@` / `@PASSWORD@` – initial user
- `@TOKEN@` – Plural bootstrap token (exchanged at runtime for an internal API token with proper access)
- `@URL@` – console hostname (e.g. `console.onplural.sh`)

---
## Option 2: Existing Linux (Bootstrap Script)

Use this when you already have an OS on the device (e.g., Raspbian, Ubuntu Server, Alpine) and don’t want to reflash.

Script location:
```
hack/k3s/bootstrap.sh
```

### Quick Start (Connected Device)
Run as root:
```bash
cd /path/on/device
./bootstrap.sh --token "$PLURAL_TOKEN" --url "console.example.com"
```

Optionally you can override `K3S_VERSION` environment variable to specify a different k3s version.
It must be a valid tag in the `k3s-bundle` image.

The script will:
1. Validate system requirements (cgroups, iptables, root)
2. Download (vendor) required assets from OCI if not already present (needs Docker)
3. Generate a persistent machine ID at /etc/plural-id
4. Template bundle manifests with bootstrap token, URL, machine ID
5. Stage additional images/manifests (Plural + trust-manager + optional images)
6. Install k3s using airgap assets (no external pulls after vendoring)

### Offline / Air‑Gapped Workflow
Perform on an internet-connected workstation of similar architecture:
```bash
cd hack/k3s
./bootstrap.sh --download-assets
# This populates: hack/k3s/assets/{k3s,plural,plural-images,plural-trust-manager}
```
Copy to the target device (USB, scp, etc.):
```bash
scp -r edge/hack/k3s /path/on/device
```
On the device, run as root:
```bash
cd /path/on/device
./bootstrap.sh --token "$PLURAL_TOKEN" --url "console.example.com"
```
Because assets are already present no downloads occur. Note: the script deletes `assets/` after a successful run—if you intend to reuse them for multiple devices, copy them aside before running or re-run with `--download-assets` again elsewhere.

### Arguments & Environment
```
-t, --token        (required unless --download-assets) Plural bootstrap token
-u, --url          (required unless --download-assets) Console hostname (no scheme)
--download-assets  Only vendor assets; skip install
-h, --help         Show help

Env:
K3S_VERSION        Exact k3s bundle image tag to install. Defaults to 1.32.0 if not set.
```

### Where Things Go
- k3s binary -> `/usr/local/bin/k3s`
- k3s images -> `/var/lib/rancher/k3s/agent/images`
- Manifests (Plural, trust-manager) -> `/var/lib/rancher/k3s/server/manifests`
- Machine ID -> `/etc/plural-id`
- Registry config -> `/etc/rancher/k3s/registries.yaml`

### Verifying
After completion:
```bash
sudo k3s kubectl get nodes
sudo k3s kubectl get pods -A | grep plural
cat /etc/plural-id
```
Check Plural Console for a newly registered edge device.

### Updating / Re-running
Re-running the script with the same machine ID is idempotent for manifests; k3s reinstall will overwrite components. To change token/URL, re-run with new values (old job will be replaced).

---
## File Reference

| File | Purpose |
|------|---------|
| `cloud-config.yaml` | Kairos cloud-config: user, k3s args, bundles, token/url templating |
| `plural-config.yaml` | Inputs for `plural edge image` (base image + bundle versions) |
| `hack/k3s/bootstrap.sh` | In-place bootstrap script for existing Linux devices |
| `hack/k3s/assets/` | (Generated) Vendored binaries, manifests, images for offline use |
| `images/*` | Dockerfiles that build the OCI bundle images consumed above |
| `rpi5/*` | Experimental / architecture-specific image build assets for Raspberry Pi 5 |

---
## Troubleshooting

| Symptom | Hint |
|---------|------|
| Script fails: "memory controller not available" | Ensure cgroups v2 memory controller enabled or use a distro with proper cgroups setup |
| k3s never becomes ready | Inspect `sudo journalctl -u k3s -e` (if systemd) or run `sudo k3s server` logs; verify enough memory |
| Pods ImagePullBackOff | Ensure `plural-images-bundle` was vendored or device has network egress |
| Device not in Console | Confirm bootstrap token & URL; look at the plural job in the `default` namespace |

---
## Security Notes
- The bootstrap token is limited-scope: it only permits initial registration and is exchanged server-side for a proper internal API token; still treat it as sensitive.
- Treat the device token like a secret; avoid committing it.
- Remove or archive vendored `assets/` if you preserve them for reuse; the script removes them automatically after successful bootstrap.

---
## Feedback
Found a gap? Open an issue or PR to refine these docs.
