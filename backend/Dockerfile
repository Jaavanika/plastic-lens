# PlasticLens API: deploy to Google Cloud Run, Render or Railway.
# Required env: ANTHROPIC_API_KEY (secret). On Cloud Run, Firebase Admin uses
# the service's default credentials; elsewhere set GOOGLE_APPLICATION_CREDENTIALS.
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /srv

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

# Cloud Run/Render inject PORT.
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
