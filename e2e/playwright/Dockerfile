FROM node:22-slim

# Install only the system-level deps Playwright Chromium needs.
# The headless shell itself is fetched by `npx playwright install chromium`.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    fonts-liberation \
    libglib2.0-0 \
    libnss3 \
    libnspr4 \
    libdbus-1-3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /e2e

COPY package.json package-lock.json* ./
RUN npm install
# Only download Chromium headless shell (~170 MB), not Firefox or WebKit.
RUN npx playwright install chromium

COPY . .

CMD ["npm", "run", "test:docker"]
