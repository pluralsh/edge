FROM alpine AS build

# renovate: datasource=github-releases depName=pluralsh/plural-cli
ENV VERSION=v0.11.1

ARG TARGETARCH

ADD "https://github.com/pluralsh/plural-cli/releases/download/plural-cli_${VERSION}_Linux_${TARGETARCH}.tar.gz" /tmp
RUN tar xvz /tmp/plural-cli_${VERSION}_Linux_${TARGETARCH}.tar.gz /tmp  && \
  ls -al /tmp && \
  mv /tmp/plural /usr/local/bin/plural && \
  chmod +x /usr/local/bin/plural

FROM --platform=$BUILDPLATFORM scratch
ARG TARGETARCH
COPY ./run.sh /
COPY --from=build /tmp/plural .
COPY ./assets /assets