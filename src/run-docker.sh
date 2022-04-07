#!/bin/bash

if [[ -t 0 && $# -eq 0 ]]; then
  docker run -v "`pwd`":"/home/" -e SECURITY_TRAILS_API_KEY --net=host -i --rm cf-bypass -h
  exit 1;
fi

docker run -v "`pwd`":"/home/" -e SECURITY_TRAILS_API_KEY --net=host -i --rm cf-bypass "$@"