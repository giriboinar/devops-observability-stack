# syntax=docker/dockerfile:1
# Multi-stage build for the instrumented demo API.
# Base image pinned and verified on Docker Hub (python:3.12-slim-bookworm).

FROM python:3.12-slim-bookworm AS builder
WORKDIR /build
COPY app/requirements.txt .
# Install runtime-only deps into a prefix; test-only packages stay out of the image.
RUN pip install --no-cache-dir --prefix=/install \
    fastapi==0.143.1 uvicorn==0.34.3 prometheus-client==0.21.1 pydantic==2.11.7

FROM python:3.12-slim-bookworm AS runtime
# Pull the latest Debian security updates: the base image tag is rebuilt
# periodically and can lag upstream fixes by days (Trivy gates on HIGH/CRITICAL).
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH=/usr/local/bin:$PATH
WORKDIR /srv/app

COPY --from=builder /install /usr/local
COPY app/ ./app/

RUN groupadd -r appuser && useradd -r -g appuser -d /srv/app appuser \
    && chown -R appuser:appuser /srv/app
USER appuser

EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/healthz')" || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
