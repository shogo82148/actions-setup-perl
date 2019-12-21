help: ## show this text
	# from http://postd.cc/auto-documented-makefile/
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

IMAGE_NAME = cpanm-packer
DOCKER_RUN = docker run --rm -v $(PWD):/tmp/cpanm -w /tmp/cpanm $(IMAGE_NAME)

.PHONY: all
all: cpanm cpanm.bat

.PHONY: image
image: .image.exists ## build docker image of packing environment
.image.exists: Dockerfile
	docker build -t $(IMAGE_NAME) .
	touch .image.exists

cpanm: .image.exists local/bin/cpanm build.pl ## generate fat-packed cpanm
	$(DOCKER_RUN) perl build.pl
	chmod +w cpanm

cpanm.bat: .image.exists cpanm
	$(DOCKER_RUN) perl -MExtUtils::PL2Bat -e 'pl2bat(in=>"cpanm")'

local/bin/cpanm: .image.exists cpanfile.snapshot
	$(DOCKER_RUN) carton install --deployment

.PHONY: update
update: .image.exists ## download dependencies and update cpanfile.snapshot
	rm -f cpanfile.snapshot
	$(DOCKER_RUN) carton install

.PHONY: install
install: all ## installs into the bin directory of this repository
	cp cpanm ../../bin/
	cp cpanm.bat ../../bin/

.PHONY: clean
clean:
	rm -rf local/
	rm -f cpanm cpanm.bat .image.exists
	docker rmi $(IMAGE_NAME)
