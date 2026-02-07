FROM r-base:latest

WORKDIR /app

# Install system dependencies for R packages
# Full upgrade first to resolve version conflicts in r-base repos
# RUN apt-get update && \
    # apt-get upgrade -y && \
    # apt-get install -y \
    #     python3 \
    #     libcurl4-openssl-dev \
    #     libssl-dev \
    #     libxml2-dev \
    #     libfontconfig1-dev \
    #     libharfbuzz-dev \
    #     libfribidi-dev \
    #     libfreetype6-dev \
    #     libpng-dev \
    #     libtiff5-dev \
    #     libjpeg-dev && \
    # rm -rf /var/lib/apt/lists/*

# Copy and install R packages (cached layer)
COPY install_packages.R .
RUN Rscript install_packages.R

CMD ["R"]
