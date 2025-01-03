ARG ALPINE_VERSION=3.21.0
ARG TOOLS_IMAGE=alpine:${ALPINE_VERSION}

FROM ${TOOLS_IMAGE} AS tools

ARG TARGETARCH=arm64
ENV CLI_VERSION=v0.11.1

RUN apk update && apk add curl
RUN curl -L https://github.com/pluralsh/plural-cli/releases/download/${CLI_VERSION}/plural-cli_${CLI_VERSION#v}_Linux_${TARGETARCH}.tar.gz | tar xvz plural && \
  mv plural /usr/local/bin/plural && \
  chmod +x /usr/local/bin/plural

FROM quay.io/kairos/alpine:3.19-standard-arm64-rpi3-v3.2.3-k3sv1.31.2-k3s1

COPY --from=tools /usr/local/bin/plural /usr/local/bin/plural
