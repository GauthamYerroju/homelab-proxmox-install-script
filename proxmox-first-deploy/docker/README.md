# Notes

### entrypoint: section in qbitttorrent compose

The hotio/qbittorrent image sets permissions for /config at maxdepth=0, so sub directories (like /config/data) won't have access if volumes are mapped for them (will be owned by root, which runs the docker daemon).

hotio.dev FAQ indicates we can place pre-init scripts in /etc/cont-init.d/, where we can chown /config recursively. Ansible can create the script, which will be mapped by the mount.
`- ${DEPLOYMENT_ASSETS_PATH}/qbittorrent/fix-subdir-ownership:/etc/cont-init.d/99-fix-subdir-ownership`

For now though, using entrypoint: to override /init script to change ownership.

TODO: Update ansible and remove the entrypoint section.

### Docker socket to port mapping

homepage might need tecnativa/docker-socket-proxy for labels in compose file to auto-populate services/