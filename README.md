# `Nimi` - Introduction

`Nimi` is a tiny process manager for running [NixOS modular services](https://nixos.org/manual/nixos/unstable/#modular-services) inside containers or other minimal environments such as dev shells. It reads a JSON config produced by `nimi.mkNimiBin`, launches each service with clean environment settings, streams logs to the console, and handles shutdown and restart policy consistently.

# Overview

`Nimi` gives you a lightweight PID 1 style runtime without pulling in a full init system. It is designed to pair with the modular services model such that you can define services once and then run them in a container, VM, or anywhere a small process manager is preferred.

# Usage

The CLI accepts a generated config file, validates it, and runs the configured services. A single optional startup command can run before services begin. Each service is started with its own `argv`, config files are materialized into a temporary config directory, and stdout/stderr are streamed to the console. On shutdown, `Nimi` forwards the signal and waits for services to exit.

# Documentation

Check out the GitHub pages website for more in depth documentation and an option search.
