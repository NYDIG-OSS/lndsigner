.PHONY: cover docker docker-itest docker-test docker-test-all docker-check docker-shell itest test test-all

IMG_NAME    := lndsigner-builder

CPLATFORM   := $(shell uname -m)

GOCOVERDIR  := /tmp/lndsigner-icover-$(shell date +%s)

ifeq ($(CPLATFORM), x86_64)
	GOPLATFORM := amd64
endif

ifeq ($(CPLATFORM), aarch64)
	GOPLATFORM := arm64
endif

ifeq ($(CPLATFORM), arm64)
	GOPLATFORM := arm64
	CPLATFORM := aarch64
endif 

GOVER         := 1.20.3
LND           := v0.16.4-beta
BITCOIND      := 25.0
VAULT         := 1.12.3

# docker builds a builder image for the host platform if one isn't cached.
docker:
	docker build -t $(IMG_NAME):latest --build-arg cplatform=$(CPLATFORM) \
		--build-arg goplatform=$(GOPLATFORM) --build-arg gover=$(GOVER) \
		--build-arg lnd=$(LND) --build-arg bitcoind=$(BITCOIND) \
		--build-arg vault=$(VAULT) -f Dockerfile.dev .

# docker-itest runs itests in a docker container, then removes the container.
docker-itest: docker
	docker run -t --rm \
		--mount type=bind,source=$(CURDIR),target=/app $(IMG_NAME):latest \
		make itest

# docker-test runs unit tests in a docker container, then removes the container.
docker-test: docker
	docker run -t --rm \
		--mount type=bind,source=$(CURDIR),target=/app $(IMG_NAME):latest \
		make test

# docker-test-all runs unit and integration tests in a docker container, then
# removes the container.
docker-test-all: docker
	docker run -t --rm \
		--mount type=bind,source=$(CURDIR),target=/app $(IMG_NAME):latest \
		make test-all

# docker-shell opens a shell to a dockerized environment with all dependencies
# and also dlv installed for easy debugging, then removes the container.
docker-shell: docker
	docker run -it --rm \
		--mount type=bind,source=$(CURDIR),target=/app $(IMG_NAME):latest \
		bash -l 

cover:
	mkdir $(GOCOVERDIR) && mkdir $(GOCOVERDIR)/lndsignerd && \
		mkdir $(GOCOVERDIR)/plugin && mkdir $(GOCOVERDIR)/combined

itest: cover
	go install -race -cover -buildvcs=false ./cmd/... && \
		GOCOVERDIR=$(GOCOVERDIR) go test -v -count=1 -race -tags=itest ./itest && \
		go tool covdata merge -pcombine -i=$(GOCOVERDIR)/lndsignerd,$(GOCOVERDIR)/plugin -o=$(GOCOVERDIR)/combined && \
		go tool covdata textfmt -i=$(GOCOVERDIR)/combined -o icover.out && \
		rm -rf $(GOCOVERDIR)

test:
	go test -v -count=1 -race -coverprofile cover.out ./...

test-all: test itest
