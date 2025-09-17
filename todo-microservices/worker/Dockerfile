FROM node:20-alpine

WORKDIR /app

COPY package.json package-lock.json* ./

RUN npm ci --production

COPY . .

ENV NODE_ENV=production
ENV DB_PORT=3306
ARG DB_NAME
ARG DB_USER
ARG DB_PASS
ARG DB_HOST

ARG RABBIT_URL

CMD ["node", "src/worker.js"]
