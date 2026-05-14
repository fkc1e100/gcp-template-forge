# Use a multi-stage build to optimize the final image size
# First stage: Build the React app
FROM node:16 as build-stage
WORKDIR /app
COPY webapp/package*.json ./
RUN npm install
COPY webapp/src ./src
COPY webapp/public ./public
RUN npm run build

# Second stage: Build the Flask API
FROM python:3.9 as api-stage
WORKDIR /app
COPY api/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY api ./api

# Final stage: Combine the built React app and Flask API
FROM nginx:alpine
COPY --from=build-stage /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
COPY --from=api-stage /app/api /app/api
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
