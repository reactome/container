# Pathway Browser & Analysis Service

`pathway-browser.dockerfile` will let you build a docker image that contains the PathwayBrowser so that you can run Reactome analyses and view them in your web browser.

This relies on a number of other components, so those images will need to be built first:

 - [content-service](../stand-alone-content-service)
 - [analysis-service](../stand-alone-analysis-service)
 - [analysis-core](../analysis-core)

Once those images have been successfully built, you can build the Pathway Browser & Analysis Service image like this:

```bash
docker build -t reactome/analysis-service-and-pwb:Release77 --build-arg RELEASE_VERSION=Release77 --build-arg GITHUB_TOKEN=$GITHUB_TOKEN -f pathway-browser.dockerfile .
```

**NOTE:** `$GITHUB_TOKEN` must be a valid github personal access token. This is needed to build the reacfoam component. You can generate a token in github under Settings -> Developer Settings -> Personal access tokens. You will need to give your token all "repo" permissions (repo:status, repo_deployment, repo_public, repo:invite, security_events) and read:repo_hook. You will also need to have access (read-access, at least) to the reacfoam repository for this to work.

You can run this docker image like this:
```bash
docker run --name docker run --name reactome-pwb-and-analysis-service -p 8080:8080 reactome/analysis-service-and-pwb:Release77
```

Navigate to http://localhost/PathwayBrowser/ to use the container. It may be a bit slow initially, this container is a bit resource-hungry.
