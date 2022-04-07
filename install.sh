#!/bin/bash

check_docker()
{
    if [ -z "$(which docker)" ]; then
        echo "Docker is not installed. Please install it first."
        exit 1
    fi
    if [ -z "$(docker info)" ]; then
        echo "Docker is not running. Please start it first."
        exit 1
    fi
}

main()
{
    # Banner
    echo "###############################################################################"
    echo "#                                                                             #"
    echo "#  This script will install cf-bypass                                         #"
    echo "#  on your system.                                                            #"
    echo "#                                                                             #"
    echo "###############################################################################"

    check_docker

    # Install
    echo "Installing cf-bypass..."
    docker build . -t cf-bypass

    # Install src/run-docker.sh as an alias

    # Check if you can write to /usr/local/bin
    if [ -w /usr/local/bin ]; then
        cp ./src/run-docker.sh /usr/local/bin/cf-bypass
        chmod +x /usr/local/bin/cf-bypass
    else
        echo "You don't have permission to write to /usr/local/bin. Please run this script as root."
        exit 1
    fi

    # Check if cf-bypass is installed correctly
    if [ -z "$(cf-bypass)" ]; then
        echo "cf-bypass is not installed correctly. Please check the installation instructions."
        exit 1
    fi
    echo -e "\033[32mcf-bypass is installed correctly.\033[0m"
}

main