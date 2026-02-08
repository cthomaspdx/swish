FROM python:2.7-slim

WORKDIR /app

# Install system dependencies needed to compile numpy for Python 2
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc g++ gfortran && \
    rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies (cached layer)
COPY requirements.txt .
RUN pip install --upgrade "pip<21" && \
    pip install --no-cache-dir -r requirements.txt

# Remove build tools to reduce image size
RUN apt-get purge -y gcc g++ gfortran && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

CMD ["python2"]
