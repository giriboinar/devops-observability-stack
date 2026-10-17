# syntax=docker/dockerfile:1
# Multi-stage build for the instrumented demo API.
# Alpine base (python:3.12-alpine3.24): minimal OS surface. Debian slim carried
# dozens of HIGH/CRITICAL CVEs with no fixed version available (bookworm: 63,
# trixie: 44), so we moved to Alpine — see CI history 2026-10-17.

FROM python:3.12-alpine3.24 AS builder
WORKDIR /build
COPY app/requirements.txt .
# Install runtime-only deps into a prefix; test-only packages stay out of the image.
RUN pip install --no-cache-dir --prefix=/install \
    fastapi==0.143.1 uvicorn==0.34.3 prometheus-client==0.21.1 pydantic==2.11.7

FROM python:3.12-alpine3.24 AS runtime
# Pull the latest Alpine security updates (the base is rebuilt frequently,
# but this guards against lag the same way apt-get upgrade did on Debian).
RUN apk upgrade --no-cache
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH=/usr/local/bin:$PATH
WORKDIR /srv/app

COPY --from=builder /install /usr/local
COPY app/ ./app/

RUN addgroup -S appuser && adduser -S -G appuser -h /srv/app appuser \
    && chown -R appuser:appuser /srv/app
USER appuser

EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/healthz')" || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
