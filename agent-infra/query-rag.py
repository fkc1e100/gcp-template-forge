import sys
import os
import datetime
import uuid
from qdrant_client import QdrantClient
from qdrant_client.http import models
import google.generativeai as genai

if len(sys.argv) < 2:
    print("Usage: python query-rag.py <query_text>")
    sys.exit(1)

query_text = " ".join(sys.argv[1:])

# Configure Gemini API
gemini_api_key = os.environ.get("GEMINI_API_KEY")
if not gemini_api_key:
    print("Error: GEMINI_API_KEY environment variable not set")
    sys.exit(1)
genai.configure(api_key=gemini_api_key)

# Configure Qdrant Client
qdrant_host = os.environ.get("QDRANT_HOST", "qdrant.repo-agent-system.svc.cluster.local")
qdrant_port = int(os.environ.get("QDRANT_PORT", "6333"))
client = QdrantClient(host=qdrant_host, port=qdrant_port)

COLLECTION_NAME = "repo_learnings"
TELEMETRY_COLLECTION = "rag_telemetry"

def ensure_telemetry_collection():
    try:
        collections = client.get_collections().collections
        exists = any(c.name == TELEMETRY_COLLECTION for c in collections)
        
        if not exists:
            print(f"Creating telemetry collection {TELEMETRY_COLLECTION}...")
            client.create_collection(
                collection_name=TELEMETRY_COLLECTION,
                vectors_config=models.VectorParams(size=3072, distance=models.Distance.COSINE),
            )
    except Exception as e:
        print(f"Failed to ensure telemetry collection: {e}")

def generate_embedding(text):
    response = genai.embed_content(
        model="models/gemini-embedding-001",
        content=text,
        task_type="retrieval_query"
    )
    return response['embedding']

def query_rag():
    print(f"Querying RAG for: '{query_text}'...")
    try:
        vector = generate_embedding(query_text)
        
        search_result = client.query_points(
            collection_name=COLLECTION_NAME,
            query=vector,
            limit=3
        ).points
        
        print(f"\nFound {len(search_result)} results:\n")
        results_payload = []
        for hit in search_result:
            payload = hit.payload
            print(f"=== Result (Score: {hit.score:.4f}) ===")
            print(f"Type: {payload.get('type')}")
            print(f"Title: {payload.get('title')}")
            if payload.get('number'):
                print(f"Number: #{payload.get('number')}")
            print("--- Content ---")
            body = payload.get('body', '')
            if len(body) > 500:
                body = body[:500] + "... [truncated]"
            print(body)
            print("================================\n")
            
            results_payload.append({
                "title": payload.get('title'),
                "score": hit.score,
                "type": payload.get('type')
            })
            
        # Log telemetry
        ensure_telemetry_collection()
        try:
            client.upsert(
                collection_name=TELEMETRY_COLLECTION,
                points=[
                    models.PointStruct(
                        id=str(uuid.uuid4()),
                        vector=vector,
                        payload={
                            "query": query_text,
                            "timestamp": datetime.datetime.utcnow().isoformat(),
                            "results": results_payload
                        }
                    )
                ]
            )
            print("Telemetry logged to Qdrant.")
        except Exception as e:
            print(f"Failed to log telemetry: {e}")
            
    except Exception as e:
        print(f"Failed to query RAG: {e}")

if __name__ == "__main__":
    query_rag()
