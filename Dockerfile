FROM marcelocg/phoenix:v1.1.4

RUN export DEBIAN_FRONTEND=noninteractive && \
  apt-get update -q && \
  apt-get -y install rebar erlang-parsetools && \
  apt-get clean -y && \
  rm -rf /var/cache/apt/*

RUN mix local.hex --force
RUN mix hex.info

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

ADD mix.exs /usr/src/app/
RUN mix do deps.get, compile

ADD package.json /usr/src/app/
RUN npm install

ADD . /usr/src/app

CMD mix phoenix.server
