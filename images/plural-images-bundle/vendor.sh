#!/bin/bash

set -e

IMAGES=(
pluralsh/kairos-plural-bundle:0.1.4
pluralsh/deployment-operator:0.5.6
pluralsh/agentk:0.0.2
)

for IMAGE in "${IMAGES[@]}"; do
  ARCHIVE=${IMAGE//\//-}
  echo "Copying $IMAGE to $ARCHIVE "
  skopeo copy docker://"$IMAGE" docker-archive:"$ARCHIVE".tar:"$IMAGE"
done

