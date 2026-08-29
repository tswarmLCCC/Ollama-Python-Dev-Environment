"""Simple one-shot generation example."""

import os

from ollama import generate

MODEL = os.getenv("OLLAMA_MODEL", "llama3.2:1b")
PROMPT = os.getenv("OLLAMA_PROMPT", "Give me three Python study tips.")

response = generate(model=MODEL, prompt=PROMPT)
print(response["response"])
