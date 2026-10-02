ARG PYTHON_BASE_IMAGE=python:3.13-slim@sha256:7c61056e61ac89e852de05f3dc6fa51a6dd2181797bceed46aa725dd7cb2cd3b
FROM ${PYTHON_BASE_IMAGE}

COPY --from=ghcr.io/astral-sh/uv:0.12.18@sha256:3adc3706091ce7c2fe595e669628caedd6d951551b92b258b7e7dbe06d9440bc /uv /usr/local/bin/uv

ARG OCI_REVISION=unknown
ARG OCI_SOURCE=unknown
ARG OCI_CREATED=unknown

LABEL org.opencontainers.image.title="Tutor TDS API" \
      org.opencontainers.image.revision="${OCI_REVISION}" \
      org.opencontainers.image.source="${OCI_SOURCE}" \
      org.opencontainers.image.created="${OCI_CREATED}" \
      org.opencontainers.image.version="${OCI_REVISION}"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TUTOR_ENVIRONMENT=production \
    PATH="/app/.venv/bin:$PATH"

WORKDIR /app

COPY pyproject.toml uv.lock ./
# Dependencies come from the same lock as QA/Cloud. Code is imported from /app;
# installing the project itself would resolve an additional unpinned build backend.
RUN uv sync --locked --no-dev --no-install-project --no-cache \
    --python /usr/local/bin/python --no-python-downloads

COPY app ./app
COPY migrations ./migrations
COPY alembic.ini ./

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
