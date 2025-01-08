FROM alpine AS build

# renovate: datasource=github-releases depName=pluralsh/plural-cli
ENV VERSION=v0.11.1
ENV PVERSION=0.11.1

ARG TARGETARCH

WORKDIR /tmp
ADD "https://github.com/pluralsh/plural-cli/releases/download/${VERSION}/plural-cli_${PVERSION}_Linux_${TARGETARCH}.tar.gz" /tmp
RUN tar -xzf /tmp/plural-cli_${PVERSION}_Linux_${TARGETARCH}.tar.gz plural && \
    chmod +x /tmp/plural

FROM --platform=$BUILDPLATFORM scratch
ARG TARGETARCH
COPY ./run.sh /
COPY --from=build /tmp/plural .
COPY ./assets /assets