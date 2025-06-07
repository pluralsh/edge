#!/bin/bash

set -e

TARGETARCH=$1

IMAGES=(
# renovate: datasource=docker packageName=ghcr.io/pluralsh/kairos-plural-cli versioning=docker
ghcr.io/pluralsh/kairos-plural-cli:0.12.0
# renovate: datasource=docker packageName=ghcr.io/pluralsh/deployment-operator versioning=docker
ghcr.io/pluralsh/deployment-operator:0.5.12
# renovate: datasource=docker packageName=ghcr.io/pluralsh/agentk versioning=docker
ghcr.io/pluralsh/agentk:0.1.0
# renovate: datasource=docker packageName=alpine/curl versioning=docker
alpine/curl:8.14.1
)

echo "Using $TARGETARCH architecture"

for IMAGE in "${IMAGES[@]}"; do
  VAR=${IMAGE//\//-}
  ARCHIVE=${VAR//\:/-}
  echo "Copying $IMAGE to $ARCHIVE..."
  skopeo copy --override-arch=$TARGETARCH docker://"$IMAGE" docker-archive:"$ARCHIVE".tar:"$IMAGE"
done

