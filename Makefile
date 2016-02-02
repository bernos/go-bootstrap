# Name of the binary to produce. This will default to whatever the name of
# the folder containing this makefile is. Can be overriden either by
# setting the NAME env var, or by specifying a new value when invoking
# make: `make NAME='foo'`
NAME ?= $(notdir $(PWD))

# The name of the docker image to create
DOCKER_IMAGE_NAME ?= $(NAME)

# Output dir
DIST_DIR ?= dist

# Build number
BUILD_NUMBER ?= 0

# Version
VERSION = $(shell cat ./version.go | grep -o "[0-9]*\.[0-9]*\.[0-9]*")-$(BUILD_NUMBER)

# Path to build artifact
BIN = $(DIST_DIR)/$(NAME)

# Golang package name
PACKAGE = $(subst $(GOPATH)/src/,,$(PWD))

ifeq ($(OS),Windows_NT)
	# Force cmd.exe as shell on windows to relieve
	# Interrupt/Exception caught (code = 0xc00000fd, addr = 0x4227d3)
	# See http://superuser.com/questions/375029/make-interrupt-exception-caught
	SHELL=C:/Windows/System32/cmd.exe
	BIN=$(DIST_DIR)/$(NAME).exe
endif

all: test

clean:
	go clean -i -x ./...
	-rm -rf $(DIST_DIR)
	-rm -rf report.xml
	-rm -rf .deps

.deps:
	go get -v github.com/tools/godep && \
	go get -v github.com/jstemmer/go-junit-report
	touch .deps

$(BIN): .deps 
	@echo "BUILDING $(NAME) VERSION $(VERSION)"
	CGO_ENABLED=0 GOOS=linux godep go build -ldflags "-X main.buildnumber=$(BUILD_NUMBER)" -a -installsuffix cgo -o $(BIN)
	# cp ./application*.yaml $(DIST_DIR)

test: $(BIN)
	godep go test -v -cover ./...

teamcity: $(BIN)
	@echo "##teamcity[buildNumber '$(VERSION)']"
	godep go test -v -cover ./... | go-junit-re port > report.xml

docker-build: test
	docker build -t $(DOCKER_IMAGE_NAME):$(VERSION) --build-arg BIN=$(BIN) --build-arg DIST_DIR=$(DIST_DIR) .

docker-push:
	docker push $(DOCKER_IMAGE_NAME):$(VERSION)

.PHONY: all clean test teamcity docker-build docker-push
