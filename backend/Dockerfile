FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN if [ -f package.json ]; then npm ci; else echo "package.json missing; install skipped for scaffold"; fi

COPY . .
RUN if [ -f package.json ]; then npm run build; fi

ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV PORT=3000

EXPOSE 3000

CMD ["sh", "-lc", "if [ -f package.json ]; then npm start --if-present || node dist/index.js; else echo 'Backend scaffold ready; package.json missing.' && tail -f /dev/null; fi"]
