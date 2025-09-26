FROM node:20-alpine

WORKDIR /frontend

COPY package.json package-lock.json* ./

RUN npm ci --production

COPY . .

ENV PORT=80
ENV API=http://api-service:3000

EXPOSE 80

CMD ["npm", "start"]
