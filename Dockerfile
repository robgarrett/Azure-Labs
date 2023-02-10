# Base Image.
FROM robgarrett/azure-cli:latest

# Create a persisted volume.
VOLUME /usr/app/azurelabs
WORKDIR /usr/app/azurelabs

# Install dependencies.
RUN apt-get update -y && apt-get -y upgrade
	
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
