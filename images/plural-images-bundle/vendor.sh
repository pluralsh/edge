#!/bin/bash

set -e

TARGETARCH=$1

# TODO: Write renovate config to keep it up to date.
IMAGES=(
ghcr.io/pluralsh/kairos-plural-cli:0.11.1
ghcr.io/pluralsh/deployment-operator:0.5.6
ghcr.io/pluralsh/agentk:0.0.2
alpine/curl:8.10.0
)

echo "Using $TARGETARCH architecture"

for IMAGE in "${IMAGES[@]}"; do
  VAR=${IMAGE//\//-}
  ARCHIVE=${VAR//\:/-}
  echo "Copying $IMAGE to $ARCHIVE..."
  skopeo copy --override-arch=$TARGETARCH docker://"$IMAGE" docker-archive:"$ARCHIVE".tar:"$IMAGE"
done

