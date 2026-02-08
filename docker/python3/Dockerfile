FROM python:3.12-slim

WORKDIR /app

# Install system dependencies needed by scipy
RUN apt-get update && \
    apt-get install -y --no-install-recommends libgfortran5 libopenblas0 && \
    rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies (pre-built wheels only)
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install --no-cache-dir --only-binary=:all: -r requirements.txt

CMD ["python3"]
