# Docker-NoiseCapt

## What is it?

This repository contains and add-on to kx1t/planefence to collect audio/noise samples and make them available to planefence.
It does not have any functionality on its own.

NoiseCapt is deployed as a Docker container and is pre-built for the following architectures:
- linux/ARMv6 (armel): older Raspberry Pi's, untested
- linux/ARMv7 (armhf): Raspberry Pi 3B+ / 4B with the standard 32 bits Raspberry OS (tested on Busted, may work but untested on Stretch or Jessie)
- linux/ARM64: Raspberry Pi 4B with Ubuntu 64 bits OS
- linux/AMD64: 64-bits PC architecture (Intel or AMD) running Debian Linux (incl. Ubuntu)
- linux/i386: 32-bits PC architecture (Intel or AMD) running Debian Linux (incl. Ubuntu)

The Docker container can be accessed on [Dockerhub (kx1t/noisecapt)](https://hub.docker.com/repository/docker/kx1t/noisecapt) and can be pulled directy using this Docker command: `docker pull kx1t/noisecapt`.

## Who is it for?


## Deploying `docker-planefence`


## Advanced configuration


### Build your own container
This repository contains a Dockerfile that can be used to build your own.
1. Pull the repository and issue the following command from the base directory of the repo:
`docker build --compress --pull --no-cache -t kx1t/noisecapt .`
2. Then simply restart the container with `pushd /opt/planefence && docker-compose up -d && popd`

# Acknowledgements, Attributions, and License
I would never have been able to do this without the huge contributions of [Mikenye](http://github.com/mikenye), [Fredclausen](http://github.com/fredclausen), and [Wiedehopf](http://github.com/wiedehopf). Thank you very much!

## Attributions

## License
This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see https://www.gnu.org/licenses/.
