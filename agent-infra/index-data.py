import subprocess
import json
import os
from qdrant_client import QdrantClient
from qdrant_client.http import models
import google.generativeai as genai

# Configure Gemini API
gemini_api_key = os.environ.get("GEMINI_API_KEY")
if not gemini_api_key:
    raise ValueError("GEMINI_API_KEY environment variable not set")
genai.configure(api_key=gemini_api_key)

# Configure Qdrant Client
# Assuming running inside cluster, service name is 'qdrant' in 'repo-agent-system'
qdrant_host = os.environ.get("QDRANT_HOST", "qdrant.repo-agent-system.svc.cluster.local")
qdrant_port_env = os.environ.get("QDRANT_PORT", "6333")
if qdrant_port_env.startswith("tcp://"):
    qdrant_port = 6333
else:
    qdrant_port = int(qdrant_port_env)
client = QdrantClient(host=qdrant_host, port=qdrant_port)

COLLECTION_NAME = "repo_learnings"

def ensure_collection():
    collections = client.get_collections().collections
    exists = False
    for c in collections:
        if c.name == COLLECTION_NAME:
            exists = True
            break
    
    if not exists:
        print(f"Creating collection {COLLECTION_NAME}")
        client.create_collection(
            collection_name=COLLECTION_NAME,
            vectors_config=models.VectorParams(size=3072, distance=models.Distance.COSINE),
        )
    else:
        print(f"Collection {COLLECTION_NAME} already exists")

def get_closed_issues():
    print("Fetching closed issues via gh CLI...")
    result = subprocess.run(
        ["gh", "issue", "list", "--state", "closed", "--json", "number,title,body", "--limit", "50"],
        capture_output=True, text=True, check=True
    )
    return json.loads(result.stdout)

def get_closed_prs():
    print("Fetching closed PRs via gh CLI...")
    result = subprocess.run(
        ["gh", "pr", "list", "--state", "closed", "--json", "number,title,body", "--limit", "50"],
        capture_output=True, text=True, check=True
    )
    return json.loads(result.stdout)

def get_pr_diff(pr_number):
    try:
        result = subprocess.run(
            ["gh", "pr", "diff", str(pr_number)],
            capture_output=True, text=True, check=True
        )
        return result.stdout
    except Exception as e:
        print(f"Failed to fetch diff for PR #{pr_number}: {e}")
        return ""

def generate_embedding(text):
    if len(text) > 20000:
        text = text[:20000] + "... [truncated]"
    response = genai.embed_content(
        model="models/gemini-embedding-001",
        content=text,
        task_type="retrieval_document",
        title="Issue/PR Learning"
    )
    return response['embedding']

def get_gke_release_notes():
    print("Fetching GKE release notes...")
    import urllib.request
    from bs4 import BeautifulSoup
    
    url = "https://cloud.google.com/kubernetes-engine/docs/release-notes"
    try:
        req = urllib.request.Request(
            url, 
            headers={'User-Agent': 'Mozilla/5.0'}
        )
        with urllib.request.urlopen(req) as response:
            html = response.read()
        
        soup = BeautifulSoup(html, 'html.parser')
        entries = []
        
        # Find all h2 tags (usually dates)
        for h2 in soup.find_all('h2'):
            date_text = h2.get_text(strip=True)
            content = []
            next_node = h2.next_sibling
            while next_node and next_node.name != 'h2':
                if next_node.name and next_node.get_text(strip=True):
                    content.append(next_node.get_text(strip=True))
                next_node = next_node.next_sibling
            
            text = f"Date: {date_text}\n" + "\n".join(content)
            
            entries.append({
                "title": f"GKE Release Notes - {date_text}",
                "body": text,
                "type": "release_note"
            })
            if len(entries) >= 20:
                break
        return entries
    except Exception as e:
        print(f"Failed to fetch release notes: {e}")
        return []

def index_external_repos():
    print("Indexing external repositories...")
    repos = [
        "GoogleCloudPlatform/cloud-foundation-toolkit",
        "GoogleCloudPlatform/cluster-toolkit",
        "GoogleCloudPlatform/kubernetes-engine-samples",
        "terraform-google-modules/terraform-google-kubernetes-engine",
        "gke-labs/gemini-for-kubernetes-development",
        "GoogleCloudPlatform/accelerated-platforms",
        "google/gke-policy-automation",
        "llm-d/llm-d"
    ]
    
    import shutil
    import tempfile
    import uuid
    
    points = []
    
    for repo in repos:
        print(f"Processing repo: {repo}...")
        temp_dir = tempfile.mkdtemp()
        try:
            # Clone the repo
            subprocess.run(
                ["gh", "repo", "clone", repo, temp_dir],
                check=True
            )
            
            # Walk through the directory
            for root, dirs, files in os.walk(temp_dir):
                for file in files:
                    if file.endswith(".md"):
                        file_path = os.path.join(root, file)
                        try:
                            with open(file_path, 'r') as f:
                                content = f.read()
                            
                            if len(content) > 20000:
                                content = content[:20000] + "... [truncated]"
                                
                            text = f"Repo: {repo}\nFile: {file}\nContent:\n{content}"
                            print(f"Generating embedding for {repo}/{file}...")
                            vector = generate_embedding(text)
                            
                            # Use UUID for external repo files to avoid collisions
                            point_id = str(uuid.uuid4())
                            
                            points.append(models.PointStruct(
                                id=point_id,
                                vector=vector,
                                payload={
                                    "title": f"{repo}/{file}",
                                    "body": content,
                                    "type": "external_repo",
                                    "repo": repo,
                                    "file": file
                                }
                            ))
                        except Exception as e:
                            print(f"Failed to process file {file_path}: {e}")
                            continue
                            
        except Exception as e:
            print(f"Failed to process repo {repo}: {e}")
        finally:
            shutil.rmtree(temp_dir)
            
    return points

def index_local_repo():
    print("Indexing target repository (fkc1e100/gcp-template-forge)...")
    import shutil
    import tempfile
    import uuid
    
    points = []
    repo = "fkc1e100/gcp-template-forge"
    temp_dir = tempfile.mkdtemp()
    try:
        # Clone the repo
        subprocess.run(
            ["gh", "repo", "clone", repo, temp_dir],
            check=True
        )
        
        # Walk through the directory
        for root, dirs, files in os.walk(temp_dir):
            for file in files:
                if file.endswith(".md"):
                    file_path = os.path.join(root, file)
                    try:
                        with open(file_path, 'r') as f:
                            content = f.read()
                        
                        if len(content) > 20000:
                            content = content[:20000] + "... [truncated]"
                            
                        text = f"Repo: {repo}\nFile: {file}\nContent:\n{content}"
                        print(f"Generating embedding for {repo}/{file}...")
                        vector = generate_embedding(text)
                        
                        point_id = str(uuid.uuid4())
                        
                        points.append(models.PointStruct(
                            id=point_id,
                            vector=vector,
                            payload={
                                "title": f"{repo}/{file}",
                                "body": content,
                                "type": "local_repo",
                                "repo": repo,
                                "file": file
                            }
                        ))
                    except Exception as e:
                        print(f"Failed to process file {file_path}: {e}")
                        continue
                        
    except Exception as e:
        print(f"Failed to process target repo {repo}: {e}")
    finally:
        shutil.rmtree(temp_dir)
        
    return points

def index_data():
    ensure_collection()
    
    points = []
    
    # Index Local Repo
    try:
        local_points = index_local_repo()
        print(f"Found {len(local_points)} local repo points. Adding to list...")
        points.extend(local_points)
    except Exception as e:
        print(f"Failed to index local repo: {e}")
    
    # Index Issues
    try:
        issues = get_closed_issues()
        print(f"Found {len(issues)} closed issues. Indexing...")
        for issue in issues:
            text = f"Title: {issue['title']}\nBody: {issue['body']}"
            print(f"Generating embedding for Issue #{issue['number']}...")
            try:
                vector = generate_embedding(text)
                points.append(models.PointStruct(
                    id=issue['number'],
                    vector=vector,
                    payload={
                        "number": issue['number'],
                        "title": issue['title'],
                        "body": issue['body'],
                        "type": "issue"
                    }
                ))
            except Exception as e:
                print(f"Failed to generate embedding for Issue #{issue['number']}: {e}")
                continue
    except Exception as e:
        print(f"Failed to get issues: {e}")

    # Index PRs
    try:
        prs = get_closed_prs()
        print(f"Found {len(prs)} closed PRs. Indexing...")
        for pr in prs:
            diff = get_pr_diff(pr['number'])
            text = f"Title: {pr['title']}\nBody: {pr['body']}\nDiff:\n{diff}"
            point_id = 10000 + pr['number']
            print(f"Generating embedding for PR #{pr['number']}...")
            try:
                vector = generate_embedding(text)
                points.append(models.PointStruct(
                    id=point_id,
                    vector=vector,
                    payload={
                        "number": pr['number'],
                        "title": pr['title'],
                        "body": pr['body'],
                        "type": "pr"
                    }
                ))
            except Exception as e:
                print(f"Failed to generate embedding for PR #{pr['number']}: {e}")
                continue
    except Exception as e:
        print(f"Failed to get PRs: {e}")

    # Index GKE Release Notes
    try:
        notes = get_gke_release_notes()
        print(f"Found {len(notes)} release note entries. Indexing...")
        counter = 0
        for note in notes:
            point_id = 20000 + counter
            print(f"Generating embedding for {note['title']}...")
            try:
                vector = generate_embedding(note['body'])
                points.append(models.PointStruct(
                    id=point_id,
                    vector=vector,
                    payload={
                        "title": note['title'],
                        "body": note['body'],
                        "type": "release_note"
                    }
                ))
                counter += 1
            except Exception as e:
                print(f"Failed to generate embedding for {note['title']}: {e}")
                continue
    except Exception as e:
        print(f"Failed to get release notes: {e}")

    # Index External Repos
    try:
        repo_points = index_external_repos()
        print(f"Found {len(repo_points)} external repo points. Adding to list...")
        points.extend(repo_points)
    except Exception as e:
        print(f"Failed to index external repos: {e}")

    if points:
        print(f"Uploading {len(points)} points to Qdrant...")
        # Upsert in chunks to avoid payload limits
        chunk_size = 50
        for i in range(0, len(points), chunk_size):
            chunk = points[i:i + chunk_size]
            print(f"Uploading chunk {i//chunk_size + 1}...")
            client.upsert(
                collection_name=COLLECTION_NAME,
                points=chunk
            )
        print("Indexing complete!")
    else:
        print("No points to upload.")

if __name__ == "__main__":
    index_data()
