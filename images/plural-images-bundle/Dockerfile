FROM quay.io/skopeo/stable:latest AS builder

WORKDIR /images
ADD --chmod=700 vendor.sh /images/vendor.sh
RUN ./vendor.sh

FROM scratch

COPY ./run.sh /
COPY --from=builder /images /assets
