# Image Build
FROM ubuntu:latest

# This line will help users to simply ^C the script if they want to exit ! :)
STOPSIGNAL SIGINT

RUN apt-get update && apt-get install -y \
    dnsutils \
    curl \
    jq

COPY ./src/cf-bypass.sh /usr/local/bin/cf-bypass
RUN chmod +x /usr/local/bin/cf-bypass

WORKDIR /home/
COPY ./test/mock.json ./test/mock.json

ENTRYPOINT ["/usr/local/bin/cf-bypass"]
