FROM registry.podium.com/engineering/ops/podium-images/elixir:1.13.1-erlang24.1.7 AS release

WORKDIR /code
ARG HEX_API_PULL_KEY
ARG CODE_RELOADER_ENABLED
ENV CODE_RELOADER_ENABLED=${CODE_RELOADER_ENABLED}
ARG MIX_ENV=prod
RUN mix hex.organization auth podium --key ${HEX_API_PULL_KEY}

COPY . .

RUN mix deps.get

RUN MIX_ENV=${MIX_ENV} mix compile --warnings-as-errors