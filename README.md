# reactome-docker
Repository for files for running a Reactome production-like environment inside a docker container.

The current branch is for developing ALPINE equivalent for mysql. And there are two files which are needed to be modified, dockerfile and docker-entrypoint.sh. Dockerfile has been modified upto  line 54 and for further changes we need to preconfigure installation of mysql. In Debian, it is achieved by using [debconf](https://serversforhackers.com/video/installing-mysql-with-debconf) as done in official image, but that is not available in alpine, so an alternative foe it might be [kickstart](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Installation_Guide/sect-kickstart-howto.html) or [expect](https://gist.github.com/Mins/4602864).

When dockerfile is complete, we can have a look at docker-entrypoint.sh