ARG RUBY_VERSION=3.3.2
FROM ruby:$RUBY_VERSION-slim

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

COPY . /root/app

WORKDIR /root/app

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
RUN . ~/.nvm/nvm.sh && nvm install 20.12.2 && nvm alias default 20.12.2 && \ 
    yarn install

RUN git clone https://github.com/4point/easy_captcha /tmp/easy_captcha
RUN rm -rf /root/app/vendor/gems/easy_captcha/
RUN mkdir -p /root/app/vendor/gems/easy_captcha && cp -r /tmp/easy_captcha/* /root/app/vendor/gems/easy_captcha

RUN gem install bundler -v 2.5.9
RUN bundle install --jobs=3 --retry=3

RUN rm -rf /tmp/*

# Install assets
RUN cd /root/app && NODE_OPTIONS=--openssl-legacy-provider bundle exec rake webpacker:compile
RUN NODE_OPTIONS=--openssl-legacy-provider bundle exec rake assets:precompile

# Listen port
EXPOSE ${PORT}

# Overwrite ruby image's entrypoint to provide open cli
#ENTRYPOINT [""]
CMD ["rails", "s", "-b", "0.0.0.0"]
