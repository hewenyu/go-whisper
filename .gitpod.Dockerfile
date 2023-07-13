FROM mcr.microsoft.com/devcontainers/go:1.20-bullseye
USER vscode
ENV SHELL=/bin/bash
RUN sudo apt-get update
RUN sudo apt-get install build-essential libsdl2-dev -y 