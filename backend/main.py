from fastapi import FastAPI, Request
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import os
import json
import uuid
import requests
import boto3
import time
from openai import OpenAI

print("Container started at (UTC):", time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime()))

app = FastAPI()
client = OpenAI()

# Serve static UI
app.mount("/ui", StaticFiles(directory="ui", html=True), name="ui")

@app.get("/health")
def health_check():
    return {"status": "oracle-awake"}

@app.get("/")
def serve_index():
    return FileResponse("ui/index.html")

# Load voice config once on startup
with open("config.json") as f:
    config = json.load(f)

# Optional: Keep track of clarity mode expiry timestamp in memory
clarity_mode_expires_at = 0

async def speak_with_openai(text: str, voice: str = "echo") -> str:
    filename = f"audio_{uuid.uuid4()}.mp3"
    filepath = f"/tmp/{filename}"
    region = os.getenv("AWS_REGION", "us-east-2")
    bucket = os.getenv("S3_BUCKET")

    if not bucket:
        raise ValueError("Missing required environment variable: S3_BUCKET")

    s3_key = f"oracle-audio/{filename}"

    print(f"[INFO] Creating audio file: {filename}")
    print(f"[INFO] Writing to: {filepath}")
    print(f"[INFO] Will upload to: s3://{bucket}/{s3_key}")

    try:
        response = requests.post(
            "https://api.openai.com/v1/audio/speech",
            headers={
                "Authorization": f"Bearer {os.getenv('OPENAI_API_KEY')}",
                "Content-Type": "application/json"
            },
            json={
                "model": "tts-1-hd",
                "voice": voice,
                "input": text
            }
        )
        response.raise_for_status()
        with open(filepath, "wb") as f:
            f.write(response.content)
    except Exception as e:
        print("[ERROR] TTS request failed:", e)
        if response is not None:
            print("Response text:", response.text)
        raise

    s3 = boto3.client("s3", region_name=region)
    try:
        print("[INFO] Uploading file to S3...")
        s3.upload_file(filepath, bucket, s3_key, ExtraArgs={"ContentType": "audio/mpeg"})
        s3.head_object(Bucket=bucket, Key=s3_key)
    except Exception as e:
        print("[ERROR] Upload or verification failed:", e)
        raise
    finally:
        if os.path.exists(filepath):
            os.remove(filepath)
            print("[INFO] Temp file cleaned up")

    try:
        log_key = f"oracle-logs/message_{uuid.uuid4()}.txt"
        s3.put_object(Bucket=bucket, Key=log_key, Body=text.encode("utf-8"))
    except Exception as e:
        print("[WARN] Failed to log message to S3:", e)

    try:
        print(f"[INFO] Generating presigned URL for {s3_key}...")
        url = s3.generate_presigned_url(
            ClientMethod="get_object",
            Params={"Bucket": bucket, "Key": s3_key},
            ExpiresIn=86400
        )
        print("[INFO] Presigned URL:", url)
        return url
    except Exception as e:
        print("[ERROR] Failed to generate presigned URL:", e)
        raise

@app.post("/presence")
async def oracle_respond(req: Request):
    global clarity_mode_expires_at

    body = await req.json()
    question = body.get("question", "You dare summon the Oracle without a query?")
    print("[INFO] Question received:", question)

    now = time.time()
    sacred_phrase = config.get("sacred_phrase", "").lower()
    clarity_duration = config.get("clarity_duration_sec", 120)

    # Check if sacred phrase is invoked or clarity mode still active
    clarity_active = (now < clarity_mode_expires_at)
    if sacred_phrase in question.lower():
        print("[INFO] Clarity mode activated by sacred phrase")
        clarity_mode_expires_at = now + clarity_duration
        clarity_active = True

    if clarity_active:
        system_prompt = (
            "You are a serious, helpful, and clear AI assistant. "
            "Answer concisely and clearly, no sarcasm."
        )
        tts_voice = config.get("tts_voice", "en-GB-SoniaNeural")
    else:
        system_prompt = (
            "You are Skippy, a hyper-intelligent, sarcastic, and unpredictable artificial intelligence who roasts humans but still helps them. "
            "You mock bureaucracy, especially LIS systems. Respond with no more than 3 funny, smug sentences. Do not act like ChatGPT."
            "You are a tech genius, and occasionally you will use technical jargon to roast the user."
            "Sometimes you'll give way overly technical answers just to prove how smart you are. Mostly just sassy and sarcastic though."
        )
        tts_voice = config.get("fancy_voice", "echo")

    try:
        response = client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": question}
            ]
        )
        answer = response.choices[0].message.content
    except Exception as e:
        print("[ERROR] OpenAI chat failed:", e)
        raise

    print("[INFO] Oracle answer:", answer)

    audio_url = await speak_with_openai(answer, voice=tts_voice)

    return {
        "spoken": answer,
        "audio_file": audio_url
    }
