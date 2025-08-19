import os, socket
from flask import Flask, jsonify

app = Flask(__name__)

@app.get("/")
def home():
    return jsonify(
        message="hello",
        color=os.getenv("COLOR", "unknown"),
        host=socket.gethostname()
    )

@app.get("/healthz")
def health():
    return "ok", 200