help: ## show this text
	# from http://postd.cc/auto-documented-makefile/
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

IMAGE_NAME = cpm-packer

.PHONY: all
all: cpm

.PHONY: image
image: .image.exists ## build docker image of packing environment
.image.exists: Dockerfile cpanfile cpanfile.snapshot build.pl
	-docker rmi $(IMAGE_NAME)
	docker build -t $(IMAGE_NAME) .
	touch .image.exists

cpm: .deps.exists build.pl ## generate fat-packed cpm
	cat build.pl | docker run --rm -i --volumes-from $(IMAGE_NAME)-deps $(IMAGE_NAME) perl -
	docker cp $(IMAGE_NAME)-deps:/tmp/cpm/cpm cpm

.PHONY: deps
deps: .deps.exists ## install dependencies
.DELETE_ON_ERROR: .deps.exists
.deps.exists: .image.exists cpanfile.snapshot
	touch .deps.exists
	-docker rm $(IMAGE_NAME)-deps
	docker create -v /tmp/cpm --name $(IMAGE_NAME)-deps $(IMAGE_NAME) /bin/true
	docker cp cpanfile $(IMAGE_NAME)-deps:/tmp/cpm/cpanfile
	docker cp cpanfile.snapshot $(IMAGE_NAME)-deps:/tmp/cpm/cpanfile.snapshot
	docker run --rm --volumes-from $(IMAGE_NAME)-deps $(IMAGE_NAME) carton install --deployment
	docker cp $(IMAGE_NAME)-deps:/tmp/cpm/local .

.PHONY: update
update: .image.exists ## download dependencies and update cpanfile.snapshot
	-docker rm $(IMAGE_NAME)-update
	docker create -v /tmp/cpm --name $(IMAGE_NAME)-update $(IMAGE_NAME) /bin/true
	docker cp cpanfile $(IMAGE_NAME)-update:/tmp/cpm/cpanfile
	docker run --rm --volumes-from $(IMAGE_NAME)-update $(IMAGE_NAME) carton install
	docker cp $(IMAGE_NAME)-update:/tmp/cpm/cpanfile.snapshot cpanfile.snapshot
	-docker rm $(IMAGE_NAME)-update

.PHONY: install
install: all ## installs into the bin directory of this repository
	cp cpm ../../bin/

.PHONY: clean
clean:
	rm -f cpm cpm.bat
	rm -f .image.exists .container.exists
	-docker rm $(IMAGE_NAME)-tmp
	-docker rm $(IMAGE_NAME)-update
	-docker rmi $(IMAGE_NAME)
