configure_colima() {
  export TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock
  export TESTCONTAINERS_HOST_OVERRIDE=$(colima ls -j | jq -r '.address')
  export DOCKER_HOST="unix://${HOME}/.colima/default/docker.sock"
}
