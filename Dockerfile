FROM swift:6.1

# Install only SQLite development headers - Swift already has build tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libsqlite3-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Set the working directory
WORKDIR /workdir

# Copy package files
COPY Package.swift Package.resolved ./

# Pre-fetch dependencies for faster builds
RUN swift package resolve

# Copy source code
COPY Sources ./Sources
COPY Tests ./Tests

# Default build command
CMD ["swift", "build", "--static-swift-stdlib", "--disable-sandbox", "--configuration", "release"]