#!/bin/bash

partprobe

image=$1

if [ -z "$image" ]; then
    echo "No image specified"
    exit 1
fi

set -ax
TEMPDIR="$(mktemp -d)"
echo $TEMPDIR
mount "${device}p1" "${TEMPDIR}"

# Copy all rpi files
cp -rfv /rpi5/* $TEMPDIR

umount "${TEMPDIR}"
