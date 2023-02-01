# Start from a small, trusted base image with the version pinned down
FROM ruby:2.7.7-slim AS base

# Required Libraries
#RUN apt-get update; apt-get install -y --no-install-recommends \ 
#    build-essential ubuntu-dev-tools apt-utils bison openssl \
#    libreadline6-dev curl git-core zlib1g \ 
#    zlib1g-dev libssl-dev libyaml-dev libxml2-dev autoconf \
#    libc6-dev ncurses-dev automake libtool
RUN apt-get update -qq && apt-get install -y --no-install-recommends \ 
    build-essential sudo gnupg2 git libvips curl

# Yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

RUN apt-get update; apt-get install -y --no-install-recommends \
    tzdata libv8-dev imagemagick libmagickwand-dev \
    libpq-dev libffi-dev \
    postgresql-client sqlite3 \
    #postgresql postgresql-contrib sqlite3 \
    nodejs redis yarn

# This stage will be responsible for installing gems and npm packages
FROM base AS dependencies

COPY Gemfile Gemfile.lock ./

# Install gems (excluding test dependencies)
RUN bundle config set without "test" && \
  bundle install --jobs=3 --retry=3

COPY package.json yarn.lock ./

# NodeJS & yarn install
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash
RUN . ~/.nvm/nvm.sh && nvm install node 19.5.0 && \ 
    nvm use 19.5.0 && nvm alias default 19.5.0 && \
    yarn install --frozen-lockfile

# We're back at the base stage
FROM base

# Create a non-root user to run the app and own app-specific files
RUN adduser app

# Switch to this user
USER app

# We'll install the app in this directory
WORKDIR /home/app

# Copy over gems from the dependencies stage
COPY --from=dependencies /usr/local/bundle/ /usr/local/bundle/

# Copy over npm packages from the dependencies stage
# Note that we have to use `--chown` here
COPY --chown=app --from=dependencies /node_modules/ node_modules/

# Finally, copy over the code
# This is where the .dockerignore file comes into play
# Note that we have to use `--chown` here
COPY --chown=app . ./

# Install assets
#RUN RAILS_ENV=production bundle exec rake assets:precompile

# Listen port
EXPOSE ${PORT}

# Launch the server
#CMD rails server -b 0.0.0.0 -P /tmp/server.pid

# Ensure binding is always 0.0.0.0, even in development, to access server from outside container
#ENV BINDING="0.0.0.0"

# Overwrite ruby image's entrypoint to provide open cli
#ENTRYPOINT [""]
CMD ["rails", "s", "-b", "0.0.0.0"]