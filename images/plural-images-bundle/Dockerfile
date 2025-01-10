FROM quay.io/skopeo/stable:latest AS builder

WORKDIR /images

ADD --chmod=700 vendor.sh ./vendor.sh

RUN ./vendor.sh

# TODO: Copy to scratch image like in https://kairos.io/docs/examples/airgap/.

RUN ls -al
