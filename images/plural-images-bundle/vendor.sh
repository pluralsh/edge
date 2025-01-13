#!/bin/bash

set -e

TARGETARCH=$1

IMAGES=(
pluralsh/kairos-plural-cli:0.11.1
pluralsh/deployment-operator:0.5.6
pluralsh/agentk:0.0.2
)

echo "Using $TARGETARCH architecture"

for IMAGE in "${IMAGES[@]}"; do
  VAR=${IMAGE//\//-}
  ARCHIVE=${VAR//\:/-}
  echo "Copying $IMAGE to $ARCHIVE..."
  skopeo copy --override-arch=$TARGETARCH docker://"$IMAGE" docker-archive:"$ARCHIVE".tar:"$IMAGE"
done

