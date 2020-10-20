# Base Image.
FROM robgarrett/azure-cli:latest

# Create a persisted volume.
VOLUME /usr/app/azurelabs
WORKDIR /usr/app/azurelabs

# Install dependencies.
RUN apt-get update -y && apt-get -y upgrade
RUN apt-get install -y --no-install-recommends \
        libc6 \
        libcurl3 \
        libgcc1 \
        libgssapi-krb5-2 \
        libicu57 \
        liblttng-ust0 \
        libssl1.0.2 \
        libstdc++6 \
        libunwind8 \
        zlib1g \
    && rm -rf /var/lib/apt/lists/*

# Install dotnet core sdk.
ENV DOTNET_SDK_VERSION 3.1.403
RUN curl -SL --output dotnet.tar.gz https://dotnetcli.blob.core.windows.net/dotnet/Sdk/$DOTNET_SDK_VERSION/dotnet-sdk-$DOTNET_SDK_VERSION-linux-x64.tar.gz \
    && mkdir -p /usr/share/dotnet \
    && tar -zxf dotnet.tar.gz -C /usr/share/dotnet \
    && rm dotnet.tar.gz \
    && ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet
ENV DOTNET_RUNNING_IN_CONTAINER true
RUN dotnet help
	
# Create a user 'azurelabs', add user to groups 'sudo' and 'azurelabs'.
# Set app volume owner to to azurelabs:azurelabs.
RUN useradd --create-home --shell /bin/bash azurelabs && \
    usermod -aG sudo azurelabs && \
    chown -R azurelabs:azurelabs /usr/app/azurelabs

# Add change directory to the bash startup.
RUN echo "cd /usr/app/azurelabs/Scripts" >> /home/azurelabs/.bashrc

# Run as 'azurelabs' user.
USER azurelabs

# Execute bash
ENTRYPOINT ["/bin/bash"]
