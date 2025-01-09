# Edge

Get Plural running on your edge devices.

## Prerequisites

- edge device — we have tested it on Raspberry Pi 4 with 8GB RAM
- memory card or another storage device — it should have at least 16 GB of size
- running management cluster that hosts Plural Console and supporting operators

## Setup

The general process of setting up your edge device is pretty straightforward, and it can be started with the following command:

```bash
curl https://raw.githubusercontent.com/pluralsh/edge/main/get-plural-edge | bash
```

Once the process completes you should flash your storage device and use it on your edge device. To flash your storage device, you can use [balenaEtcher](https://etcher.balena.io) or shell command:

```bash
sudo dd of=<device_path> oflag=sync status=progress bs=<bs>
```
Where:
- `device_path` is a path of your storage device, i.e. `/dev/rdisk4`
- `bs` is block size, i.e. `10m` (on macOS) or `10MB` (on Linux)