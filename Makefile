DOCKER_IMAGE_NAME := tenstartups/nginx-proxy:latest
PLATFORMS ?= linux/amd64,linux/arm64

build: Dockerfile
	docker build --file Dockerfile --tag $(DOCKER_IMAGE_NAME) .

clean_build: Dockerfile
	docker build --no-cache --pull --file Dockerfile --tag $(DOCKER_IMAGE_NAME) .

run: build
	docker run -it --rm \
		-e HTTP_LISTEN_PORT=8080 \
		-p 8080:8080 \
		-v "$(PWD)/test-config":/data:ro \
		-e BASIC_AUTH_USER=basic_auth_user:basic_auth_pass \
		-e NGINX_CONFIG_SOURCE=/data \
		$(DOCKER_IMAGE_NAME) $(ARGS)

push: Dockerfile
	docker buildx build --platform $(PLATFORMS) --file Dockerfile --tag $(DOCKER_IMAGE_NAME) --push .
