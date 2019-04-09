# Base Image.
FROM mcr.microsoft.com/azure-cli:latest

# Create a persisted volume.
VOLUME /usr/app/azurelabs
WORKDIR /usr/app/azurelabs

# Packages.
RUN set -ex && apk --no-cache add sudo
RUN apk update && \
    apk upgrade

# Create a user 'azurelabs', add user to groups 'sudo' and 'azurelabs'.
# Set app volume owner to to azurelabs:azurelabs.
RUN addgroup -S azurelabs && adduser -S azurelabs -G azurelabs && \
    chown -R azurelabs:azurelabs /usr/app/azurelabs

# Run as 'azurelabs' user.
USER azurelabs

# Execute bash
CMD /bin/bash

