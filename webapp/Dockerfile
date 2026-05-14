FROM node:16

WORKDIR /app

COPY webapp/package*.json ./

RUN npm install

COPY webapp/src ./src
COPY webapp/public ./public

CMD ["npm", "start"]
