# Base Image.
FROM debian:stretch

# Create a persisted volume.
VOLUME /usr/app/azurelabs
WORKDIR /usr/app/azurelabs

RUN apt-get update && apt-get install -qqy curl apt-transport-https lsb-release gpg jq
RUN curl -sL https://packages.microsoft.com/keys/microsoft.asc | \
    gpg --dearmor | \
    tee /etc/apt/trusted.gpg.d/microsoft.asc.gpg > /dev/null
RUN AZ_REPO=$(lsb_release -cs) && \
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | \
    tee /etc/apt/sources.list.d/azure-cli.list
RUN apt-get update && apt-get install -qqy azure-cli

# Create a user 'azurelabs', add user to groups 'sudo' and 'azurelabs'.
# Set app volume owner to to azurelabs:azurelabs.
RUN useradd --create-home --shell /bin/bash azurelabs && \
    usermod -aG sudo azurelabs && \
    chown -R azurelabs:azurelabs /usr/app/azurelabs

# Run as 'azurelabs' user.
USER azurelabs

# Execute bash
ENTRYPOINT ["/bin/bash"]
