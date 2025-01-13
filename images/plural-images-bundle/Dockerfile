FROM quay.io/skopeo/stable:latest AS builder

ARG TARGETARCH

WORKDIR /images
ADD --chmod=700 vendor.sh /images/vendor.sh
RUN ./vendor.sh

FROM scratch

ARG TARGETARCH

# renovate: datasource=github-releases depName=k3s-io/k3s
ENV K3S_VERSION="v1.32.0+k3s1"
ADD "https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s-airgap-images-${TARGETARCH}.tar" /assets

COPY ./run.sh /
COPY --from=builder /images /assets
