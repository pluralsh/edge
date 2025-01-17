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

## Setup on Raspberry Pi 4

The general process of setting up your Raspberry Pi 4 is pretty straightforward,
and it can be started with the following command:

```bash
curl -fsSL -o get-plural-edge-rpi4 https://raw.githubusercontent.com/pluralsh/edge/main/get-plural-edge-rpi4
chmod 700 get-plural-edge-rpi4
./get-plural-edge-rpi4
```

We recommend running it from an empty directory.

The current setup assumes that Raspberry Pi is connected to the network via Ethernet cable.
