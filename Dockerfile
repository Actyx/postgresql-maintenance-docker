FROM actyx/docker-alpine-cron:latest

ARG BUILD_DIR=.

# Install dependencies and AWS CLI
RUN apk add --update --no-cache \
    bash \
    postgresql-client \
    gzip \
    python3 \
    python3-dev \
    py-pip \
    build-base \
    && pip install awscli \
    && apk --purge -v del py-pip

# Copy backup script to container
COPY ${BUILD_DIR}/scripts/* /usr/bin/
