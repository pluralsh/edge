FROM alpine AS build

ARG TARGETARCH

# renovate: datasource=github-releases depName=pluralsh/plural-cli
ENV PLURAL_VERSION=0.11.1
ADD "https://github.com/pluralsh/plural-cli/releases/download/v${PLURAL_VERSION}/plural-cli_${PLURAL_VERSION}_Linux_${TARGETARCH}.tar.gz" /
RUN tar -xzvf /plural-cli_${PLURAL_VERSION}_Linux_${TARGETARCH}.tar.gz plural

# renovate: datasource=github-releases depName=helm/helm
ENV HELM_VERSION=v3.15.1
ADD "https://get.helm.sh/helm-${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" /
RUN tar -xzvf /helm-${HELM_VERSION}-linux-${TARGETARCH}.tar.gz linux-${TARGETARCH}/helm

FROM --platform=$BUILDPLATFORM scratch

ARG TARGETARCH

COPY --from=build --chmod=755 /plural .
COPY --from=build --chmod=755 /linux-${TARGETARCH}/helm .

ENTRYPOINT [ "/plural" ]