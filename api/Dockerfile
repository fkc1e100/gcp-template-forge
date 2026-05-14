FROM python:3.9-slim-buster

WORKDIR /app

COPY api/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY api/. ./

EXPOSE 5000

CMD ["flask", "run", "--host=0.0.0.0"]
