FROM docker.io/library/golang:1.23.2-alpine3.20 as builder

# Install 'make' and other necessary build tools
RUN apk add --no-cache make gcc musl-dev git

WORKDIR /go/src/github.com/indicalabs/vault-sidekick

# Copy project files (excluding .git due to .dockerignore)
COPY . .

# Run the make build command
RUN make build

FROM alpine:3.20

RUN apk update && apk upgrade
RUN apk add --no-cache ca-certificates bash

RUN adduser -D vault

COPY --from=builder /go/src/github.com/indicalabs/vault-sidekick /vault-sidekick

# Add vault-sidekick to the PATH
ENV PATH="/vault-sidekick/bin:${PATH}"

RUN chmod 755 /vault-sidekick

# Copy pull scripts to /usr/local/bin and set execute permissions
COPY pull_aws_secrets.sh /usr/local/bin/pull_aws_secrets.sh
COPY pull_gcp_secrets.sh /usr/local/bin/pull_gcp_secrets.sh
COPY pull_azure_secrets.sh /usr/local/bin/pull_azure_secrets.sh

RUN chmod +x /usr/local/bin/pull_aws_secrets.sh \
    /usr/local/bin/pull_gcp_secrets.sh \
    /usr/local/bin/pull_azure_secrets.sh

USER vault

ENTRYPOINT ["vault-sidekick"]
