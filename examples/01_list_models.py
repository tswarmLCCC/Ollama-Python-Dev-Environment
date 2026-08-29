"""List models available in the local Ollama server."""

from ollama import Client

client = Client(host="http://127.0.0.1:11434")

for model in client.list().models:
    print(model.model)
