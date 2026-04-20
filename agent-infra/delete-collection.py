import os
from qdrant_client import QdrantClient

qdrant_host = os.environ.get("QDRANT_HOST", "qdrant.repo-agent-system.svc.cluster.local")
qdrant_port_env = os.environ.get("QDRANT_PORT", "6333")
if qdrant_port_env.startswith("tcp://"):
    qdrant_port = 6333
else:
    qdrant_port = int(qdrant_port_env)
client = QdrantClient(host=qdrant_host, port=qdrant_port)

COLLECTION_NAME = "repo_learnings"

print(f"Deleting collection {COLLECTION_NAME}...")
try:
    client.delete_collection(collection_name=COLLECTION_NAME)
    print("Collection deleted!")
except Exception as e:
    print(f"Failed to delete collection: {e}")
