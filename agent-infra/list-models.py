import os
import google.generativeai as genai

gemini_api_key = os.environ.get("GEMINI_API_KEY")
if not gemini_api_key:
    raise ValueError("GEMINI_API_KEY environment variable not set")
genai.configure(api_key=gemini_api_key)

print("Listing models...")
try:
    for m in genai.list_models():
        print(f"Model: {m.name}")
        print(f"  Supported methods: {m.supported_generation_methods}")
except Exception as e:
    print(f"Failed to list models: {e}")
