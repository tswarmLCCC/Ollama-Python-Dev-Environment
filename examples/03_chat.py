"""Simple chat example for local Ollama model."""

import os

from ollama import chat

MODEL = os.getenv("OLLAMA_MODEL", "llama3.2:1b")

messages = [
    {"role": "system", "content": "You are a concise Python tutor."},
    {"role": "user", "content": "Explain list comprehensions with one short example."},
]

response = chat(model=MODEL, messages=messages)
print(response["message"]["content"])
