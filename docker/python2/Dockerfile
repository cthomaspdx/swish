FROM python:2.7-slim

WORKDIR /app

# Point to Debian archive since Buster is EOL
RUN echo "deb http://archive.debian.org/debian buster main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security buster/updates main" >> /etc/apt/sources.list

# Install system dependencies needed to compile numpy for Python 2
RUN apt-get -o Acquire::Check-Valid-Until=false update && \
    apt-get install -y --no-install-recommends gcc g++ gfortran && \
    rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies (cached layer)
COPY requirements.txt .
RUN pip install --upgrade "pip<21" && \
    pip install --no-cache-dir -r requirements.txt

# Remove build tools to reduce image size
RUN apt-get -o Acquire::Check-Valid-Until=false purge -y gcc g++ gfortran && \
    apt-get -o Acquire::Check-Valid-Until=false autoremove -y && \
    rm -rf /var/lib/apt/lists/*

CMD ["python2"]
