help: ## show this text
	# from http://postd.cc/auto-documented-makefile/
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

IMAGE_NAME = cpanm-packer

.PHONY: all
all: cpanm

.PHONY: image
image: .image.exists ## build docker image of packing environment
.DELETE_ON_ERROR: .image.exists
.image.exists: Dockerfile
	touch .image.exists
	-docker rmi $(IMAGE_NAME)
	docker build -t $(IMAGE_NAME) .

cpanm: .deps.exists build.pl
	docker cp cpanm.PL $(IMAGE_NAME)-deps:/tmp/cpanm/cpanm.PL
	cat build.pl | docker run --rm -i --volumes-from $(IMAGE_NAME)-deps $(IMAGE_NAME) perl -
	docker cp $(IMAGE_NAME)-deps:/tmp/cpanm/cpanm cpanm

.PHONY: deps
deps: .deps.exists ## install dependencies
.DELETE_ON_ERROR: .deps.exists
.deps.exists: .image.exists cpanfile.snapshot patches/*.patch
	touch .deps.exists
	-docker rm $(IMAGE_NAME)-deps
	docker create -v /tmp/cpanm --name $(IMAGE_NAME)-deps $(IMAGE_NAME) /bin/true
	docker cp cpanfile $(IMAGE_NAME)-deps:/tmp/cpanm/cpanfile
	docker cp cpanfile.snapshot $(IMAGE_NAME)-deps:/tmp/cpanm/cpanfile.snapshot
	docker cp lib $(IMAGE_NAME)-deps:/tmp/cpanm/lib
	docker run --rm --volumes-from $(IMAGE_NAME)-deps $(IMAGE_NAME) carton install --deployment
	cat patches/*.patch | docker run --rm -i --volumes-from $(IMAGE_NAME)-deps -w /tmp/cpanm/local/lib/perl5 $(IMAGE_NAME) patch -s -f -p0

.PHONY: update
update: .image.exists ## download dependencies and update cpanfile.snapshot
	-docker rm $(IMAGE_NAME)-update
	docker create -v /tmp/cpanm --name $(IMAGE_NAME)-update $(IMAGE_NAME) /bin/true
	docker cp cpanfile $(IMAGE_NAME)-update:/tmp/cpanm/cpanfile
	docker run --rm --volumes-from $(IMAGE_NAME)-update $(IMAGE_NAME) carton install
	docker cp $(IMAGE_NAME)-update:/tmp/cpanm/cpanfile.snapshot cpanfile.snapshot
	-docker rm $(IMAGE_NAME)-update

.PHONY: install
install: all ## installs into the bin directory of this repository
	cp cpanm ../../bin/

.PHONY: clean
clean:
	-rm -f .*.exists
	-docker rm $(IMAGE_NAME)-deps
	-docker rm $(IMAGE_NAME)-update
	-docker rmi $(IMAGE_NAME)
