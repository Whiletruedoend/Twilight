# Start from a small, trusted base image with the version pinned down
FROM ruby:3.3.2-slim AS base

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
    libpng-dev libjpeg-dev libtiff-dev ffmpeg \
    tzdata libv8-dev imagemagick libmagickwand-dev \
    libpq-dev libffi-dev \
    postgresql-client \
    nodejs redis yarn

# This stage will be responsible for installing gems and npm packages
FROM base AS dependencies

COPY Gemfile ./

# For EasyCaptcha install
#RUN git clone https://github.com/4point/easy_captcha /vendor/gems/easy_captcha
COPY ./vendor/gems/easy_captcha /vendor/gems/easy_captcha

# Install gems (excluding test dependencies)
RUN gem install bundler -v 2.5.9
  
RUN bundle install --jobs=3 --retry=3

COPY package.json yarn.lock ./

# NodeJS & yarn install
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
RUN . ~/.nvm/nvm.sh && nvm install 20.12.2 && nvm alias default 20.12.2 && \ 
    yarn install

# We're back at the base stage
FROM base

# Create a non-root user to run the app and own app-specific files

# Switch to this user

# We'll install the app in this directory

# Copy over gems from the dependencies stage
COPY --from=dependencies /usr/local/bundle/ /usr/local/bundle/

# Copy over npm packages from the dependencies stage
# Note that we have to use `--chown` here

COPY --from=dependencies /node_modules/ /root/app/node_modules/

# Finally, copy over the code
# This is where the .dockerignore file comes into play
# Note that we have to use `--chown` here
#RUN mkdir -p /root/app
COPY .  /root/app/

# For EasyCaptcha install
COPY --from=dependencies /vendor/gems/ /root/app/vendor/gems/

WORKDIR /root/app

# Install assets
RUN cd /root/app && bundle exec rake webpacker:compile && bundle exec rake assets:precompile

# Listen port
EXPOSE ${PORT}

# Launch the server
#CMD rails server -b 0.0.0.0 -P /tmp/server.pid

# Ensure binding is always 0.0.0.0, even in development, to access server from outside container
#ENV BINDING="0.0.0.0"

# Overwrite ruby image's entrypoint to provide open cli
#ENTRYPOINT [""]
CMD ["rails", "s", "-b", "0.0.0.0"]