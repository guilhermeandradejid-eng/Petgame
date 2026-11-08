FROM node:22-alpine
WORKDIR /app
COPY package.json relay.js ./
RUN npm install --omit=dev
ENV PORT=9080
EXPOSE 9080
CMD ["node", "relay.js"]
