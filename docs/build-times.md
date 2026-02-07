# Build Time Analysis

## Build Times

| Image | Cold Build (no cache) | Warm Build (cached) |
|-------|----------------------|---------------------|
| swish-python3 | ~2-4 min | ~5-10 sec |
| swish-python2 | ~1-3 min | ~5-10 sec |
| swish-r | ~10-15 min | ~5-10 sec |

*R builds are significantly slower due to compiling R packages from source.*

## Optimization Strategies Applied

### 1. Slim/Minimal Base Images
- Python images use `python:3.12-slim` and `python:2.7-slim` instead of full Debian images
- Reduces base image size by ~600MB

### 2. Layer Ordering
- System dependencies installed before application code
- `requirements.txt` / `install_packages.R` copied and installed before any app code
- This ensures dependency layers are cached across builds when only application code changes

### 3. .dockerignore
- Excludes `.git`, `docs`, `k8s`, and other non-build files from the build context
- Reduces context transfer time and prevents cache invalidation from unrelated changes

### 4. BuildKit Cache (CI/CD)
- GitHub Actions workflow uses `cache-from: type=gha` and `cache-to: type=gha,mode=max`
- Caches all layers in GitHub Actions cache, dramatically speeding up CI builds

### 5. Cleanup in Build Layers
- Build tools (gcc, g++) are installed, used, then removed in subsequent layers
- `apt-get` lists cleaned with `rm -rf /var/lib/apt/lists/*`
- `pip install --no-cache-dir` prevents pip from storing download caches

### 6. Parallel Package Installation
- R packages installed with `Ncpus = parallel::detectCores()` to use all available cores

## Further Improvements

- **Multi-stage builds**: For production images, copy only runtime artifacts from a builder stage
- **Pinned base image digests**: Use `python:3.12-slim@sha256:...` for reproducible builds
- **Pre-built wheels**: Host a private PyPI with pre-compiled wheels for numpy/scipy
