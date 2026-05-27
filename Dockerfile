FROM ruby:3.3.6-slim

WORKDIR /app

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
  build-essential \
  curl \
  libpq-dev \
  nodejs \
  postgresql-client \
  && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3000

ENTRYPOINT ["./bin/docker-entrypoint"]
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
