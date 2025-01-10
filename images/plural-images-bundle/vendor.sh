#!/bin/bash

set -e

IMAGES=(
pluralsh/kairos-plural-cli:0.11.1
pluralsh/deployment-operator:0.5.6
pluralsh/agentk:0.0.2
)

for IMAGE in "${IMAGES[@]}"; do
  VAR=${IMAGE//\//-}
  ARCHIVE=${VAR//\:/-}
  echo "Copying $IMAGE to $ARCHIVE "
  skopeo copy docker://"$IMAGE" docker-archive:"$ARCHIVE".tar:"$IMAGE"
done

