# Use lightweight Python base
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies for TTS + audio
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libgl1 \
    && rm -rf /var/lib/apt/lists/*

# Install Python deps
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy project files
COPY ./backend ./backend
COPY ./ui ./ui
COPY ./config.json ./config.json

# Expose backend port
EXPOSE 8000

# Start FastAPI backend
CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000"]
