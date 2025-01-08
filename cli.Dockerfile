FROM alpine AS build

ARG TARGETARCH

# FIXME: Parse PLURAL_VERSION
ENV PVERSION=0.11.1

WORKDIR /tmp

# renovate: datasource=github-releases depName=pluralsh/plural-cli
ENV PLURAL_VERSION=v0.11.1
ADD "https://github.com/pluralsh/plural-cli/releases/download/${PLURAL_VERSION}/plural-cli_${PVERSION}_Linux_${TARGETARCH}.tar.gz" /tmp
RUN tar -xzvf /tmp/plural-cli_${PVERSION}_Linux_${TARGETARCH}.tar.gz plural

# renovate: datasource=github-releases depName=helm/helm
ENV HELM_VERSION=v3.15.1
ADD "https://get.helm.sh/helm-${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" /tmp
RUN tar -xzvf /tmp/helm-${HELM_VERSION}-linux-${TARGETARCH}.tar.gz linux-${TARGETARCH}/helm

FROM --platform=$BUILDPLATFORM scratch

ARG TARGETARCH

COPY --from=build --chmod=755 /tmp/plural .
COPY --from=build --chmod=755 /tmp/linux-${TARGETARCH}/helm .
