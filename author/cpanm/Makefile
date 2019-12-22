help: ## show this text
	# from http://postd.cc/auto-documented-makefile/
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

IMAGE_NAME = cpanm-packer

.PHONY: all
all: cpanm cpanm.bat

.PHONY: image
image: .image.exists ## build docker image of packing environment
.image.exists: Dockerfile cpanfile cpanfile.snapshot build.pl
	-docker rmi $(IMAGE_NAME)
	docker build -t $(IMAGE_NAME) .
	touch .image.exists

.container.exists: .image.exists
	-docker rm $(IMAGE_NAME)-tmp
	docker run --name $(IMAGE_NAME)-tmp $(IMAGE_NAME) perl build.pl
	touch .container.exists

cpanm: .container.exists ## generate fat-packed cpanm
	docker cp $(IMAGE_NAME)-tmp:/tmp/cpanm/cpanm cpanm

cpanm.bat: .container.exists ## generate fat-packed cpanm batch file
	docker cp $(IMAGE_NAME)-tmp:/tmp/cpanm/cpanm.bat cpanm.bat

.PHONY: update
update: .image.exists ## download dependencies and update cpanfile.snapshot
	-docker rm $(IMAGE_NAME)-update
	docker run --name $(IMAGE_NAME)-update $(IMAGE_NAME) \
		sh -c "rm -f cpanfile.snapshot && rm -rf local && carton install"
	docker cp $(IMAGE_NAME)-update:/tmp/cpanm/cpanfile.snapshot cpanfile.snapshot

.PHONY: install
install: all ## installs into the bin directory of this repository
	cp cpanm ../../bin/
	cp cpanm.bat ../../bin/

.PHONY: clean
clean:
	rm -f carton carton.bat
	rm -f .image.exists .container.exists
	-docker rm $(IMAGE_NAME)-tmp
	-docker rm $(IMAGE_NAME)-update
	-docker rmi $(IMAGE_NAME)
