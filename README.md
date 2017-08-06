# Reactome Container

Reactome is an online bioinformatics database of human biology described in molecular terms. It is an on-line encyclopedia of core human pathways. This repository will enable users to setup a standalone reactome server on their own system.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development, testing and general purposes. See deployment for notes on how to deploy the project on a live system.

### Prerequisites

The things you need to install are packed in the file [prereqs-ubuntu.sh](https://github.com/reactome/container/blob/master/prereqs-ubuntu.sh) and you can begin by cloning this repo, and then you may proceed with installing prerequisites with the help of [prereqs-ubuntu.sh](https://github.com/reactome/container/blob/master/prereqs-ubuntu.sh).

### Installing


You can copy following commands to get started. Installation file prereqs-ubuntu.sh uses sudo permissions for a brief moment, so you may be prompted for your password when you execute these commands.

```
git clone https://github.com/reactome/container.git
cd container
./prereqs-ubuntu.sh
```

The script provided installs prerequisites on ubuntu. In case you are on a different platform, you can install these components manually. Following packages are installed by the script:

1. Curl
2. [Docker-CE](https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/#install-docker-ce): Version [17.06.0](https://github.com/docker/docker-ce/releases)
3. [Docker-Compose](https://docs.docker.com/compose/install/): Version [1.15.0](https://github.com/docker/compose/releases)

If you are installing or have already installed them, please verify their versions.

```
docker-compose --version # Should be 1.10.0+
docker --version # Also known as docker engine, should be 1.13.0+
```
We are using V3 of compose file format, which was intoduced in [Compose release 1.10.0](https://github.com/docker/compose/releases/tag/1.10.0). As per [compatibility matrix](https://docs.docker.com/compose/compose-file/compose-versioning/#compatibility-matrix), it requires docker-engine 1.13.0 or higher.

## Running the tests

Explain how to run the automated tests for this system

### Break down into end to end tests

Explain what these tests test and why

```
Give an example
```

### And coding style tests

Explain what these tests test and why

```
Give an example
```

## Deployment

Add additional notes about how to deploy this on a live system

## Built With

* [Dropwizard](http://www.dropwizard.io/1.0.2/docs/) - The web framework used
* [Maven](https://maven.apache.org/) - Dependency Management
* [ROME](https://rometools.github.io/rome/) - Used to generate RSS Feeds

## Contributing

Please read [CONTRIBUTING.md](https://gist.github.com/PurpleBooth/b24679402957c63ec426) for details on our code of conduct, and the process for submitting pull requests to us.

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/your/project/tags). 

## Authors

* **Billie Thompson** - *Initial work* - [PurpleBooth](https://github.com/PurpleBooth)

See also the list of [contributors](https://github.com/your/project/contributors) who participated in this project.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

* Hat tip to anyone who's code was used
* Inspiration
* etc
