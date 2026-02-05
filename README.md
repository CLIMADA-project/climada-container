# Containerization of CLIMADA

This repository documents one possible path to containerize the natural catastrophe impact model CLIMADA.

More information about CLIMADA can be found in its two repositories:

1. the core [climada_python](https://github.com/CLIMADA-project/climada_python) [start here]
2. the petals [climada_petals](https://github.com/CLIMADA-project/climada_petals)

Currently, this repository contains ONE of several ways to containerize CLIMADA that is targeted to an operational and 
secure environment. There are several other possibilities to do a containerization that are simpler and more useful for 
other purposes. This implementation was created by [MeteoeSwiss](https://github.com/MeteoSwiss) to fulfill the following needs:
- no powerful python package manager should remain in the final docker image
- only restricted internet access will be allowed for running the container, thus save the most basic plotting layers
- reasonable container size
- dependencies are stable between several re-builds to allow a stable python environment
- dependency updates are still manageable with the same dockerfile

This example should serve simply as a recipe to create a similar container in an operational environment. 
If you have your own dependencies for an application just add them to the project.toml instead of the jupyter dependencies and recreate the poetry.lock file.  

Feedback on the usefulness of this or other containerization approaches is very welcome.
## Getting started

This containerization was tested on Linux with Linux containers.
It currently works for a specific CLIMADA version (4.0.0 climada_python, combined with 4.0.1 climada_petals)
To build and run containers [podman](https://podman.io/) is used (also [docker](https://www.docker.com/) should work).
You can try it out on most linux systems with the following commands in a terminal:
1. Install podman
   ```shell
   sudo apt-get install podman
   ```
2. build the docker image
   ```shell
   podman build -f Dockerfile . -t climada_container --network=host
   ```
3. run the image as a container
   ```shell
   podman run -f Dockerfile . -t climada_container --network=host
   ```
   In the log open the link http://127.0.0.1:8888/lab?token=.......

