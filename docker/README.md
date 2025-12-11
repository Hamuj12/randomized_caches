# Docker

To build the environment for the artifact, follow these steps:

1. docker build -t randomized-caches .

This builds an image containing the configuration needed for testing. It also sets up the repository inside the docker image.

2. docker run -it -v /path/to/local/spec:/home/spec randomized-caches

This command runs the container and mounts the local SPEC installation to `/home/spec` within the container.

3. Inside the container, execute `export SPEC_PATH=/home/spec` and `export BASE_DIR=/home/randomized_caches` to set up the environment.



The container would now be ready for testing.
