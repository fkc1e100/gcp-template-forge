#!/bin/bash
pip install google-generativeai qdrant-client

echo "========================================"
echo "Query 1: What are the mandates for KCC templates regarding file placement?"
python /scripts/query-rag.py "What are the mandates for KCC templates regarding file placement?"
echo "========================================"

echo "Query 2: How do I fix a scale down blocked by pod error in repo-agent?"
python /scripts/query-rag.py "How do I fix a scale down blocked by pod error in repo-agent?"
echo "========================================"

echo "Query 3: What is the quota project requirement for User ADC in Go Cloud Functions?"
python /scripts/query-rag.py "What is the quota project requirement for User ADC in Go Cloud Functions?"
echo "========================================"

echo "Query 4: How does the self-updating wrapper pattern prevent infinite launch loops?"
python /scripts/query-rag.py "How does the self-updating wrapper pattern prevent infinite launch loops?"
echo "========================================"

echo "Query 5: What is the recommended model for vLLM inference in Issue 31?"
python /scripts/query-rag.py "What is the recommended model for vLLM inference in Issue 31?"
echo "========================================"

echo "Query 6: What are the latest GKE features included in PR 29?"
python /scripts/query-rag.py "What are the latest GKE features included in PR 29?"
echo "========================================"

echo "Query 7: How do I authenticate the dashboard sync?"
python /scripts/query-rag.py "How do I authenticate the dashboard sync?"
echo "========================================"

echo "Query 8: What is the command to view logs of a sandbox pod?"
python /scripts/query-rag.py "What is the command to view logs of a sandbox pod?"
echo "========================================"

echo "Query 9: What is the role of Overseer in the autonomous loop?"
python /scripts/query-rag.py "What is the role of Overseer in the autonomous loop?"
echo "========================================"

echo "Query 10: What are the supported machine types for the CRD build?"
python /scripts/query-rag.py "What are the supported machine types for the CRD build?"
echo "========================================"
