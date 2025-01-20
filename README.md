# Edge

Get Plural running on your edge devices.

## Prerequisites

- edge device — we have tested it on Raspberry Pi 4 with 8GB RAM
- memory card or another storage device — it should have at least 16 GB of size
- running management cluster that hosts Plural Console and supporting operators

## Bundles

- `kairos-plural-bundle` — core Plural bundle that creates job in the k3s cluster that connects it to the Plural Console.
- `kairos-plural-images-bundle` — contains bundled container images to speed up initial device boot (optional).
- `kairos-plural-trust-manager-bundle` — installs cert-manager and trust-manager in the k3s cluster (optional).

## Setup

The general process of setting up your edge device is pretty straightforward,
and it can be done with Plural CLI ([quickstart docs](https://docs.plural.sh/deployments/cli-quickstart)):

```bash
plural edge image
```
