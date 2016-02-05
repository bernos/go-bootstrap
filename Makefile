################################################################################
# This makefile should be able to build most golang > docker projects without
# much modification.
################################################################################

# Name of the binary to produce. This will default to whatever the name of the
# folder containing this makefile is. Can be overriden either by setting the
# NAME env var, or by specifying a new value when invoking make:
# `make NAME='foo'`
NAME ?= $(notdir $(PWD))

# Our source files
SRC_DIR ?= ./src

# Output dir
DIST_DIR ?= ./dist

# The name of the docker image to create. Can be overriden either by setting the
# DOCKER_IMAGE_NAME env var, or by specifying DOCKER_IMAGE_NAME when invoking
# make: `make DOCKER_IMAGE_NAME='user/image'`
DOCKER_IMAGE_NAME ?= $(NAME)

# The docker registry for tagging and pushing to
DOCKER_REGISTRY ?= dockerregistry.seekinfra.com

# Extra asset files, such as configuration files etc that need to be copied to
# the dist folder as part of the build. By default this will be any file in
# our source dir that is not a .go source file
ASSET_FILES = $(filter-out $(wildcard $(SRC_DIR)/*.go), $(wildcard $(SRC_DIR)/*))

# Any go tooling that needs to be installed to run the build. Each of these
# will be passed to `go get -v ...`
GO_GET = github.com/tools/godep \
		 github.com/jstemmer/go-junit-report

# Build number. This will normally be set by a CI server BUILD_NUMBER env var,
# but you can alternatively set it when invoking make by using
# `make BUILD_NUMBER=123`
BUILD_NUMBER ?= 0

# Version number form `0.0.0-0`. Set the base version number in version.txt
VERSION ?= $(shell cat version.txt)-$(BUILD_NUMBER)

# Path to build artifact
BIN = $(DIST_DIR)/$(NAME)

# Golang package name
PACKAGE = $(subst $(GOPATH)/src/,,$(PWD))

# Command that will run our tests
TEST_CMD = godep go test -v -cover $(SRC_DIR)/...

# A nice banner to let users know what we're building
BANNER = "BUILDING $(NAME) VERSION $(VERSION)"

ifeq ($(OS),Windows_NT)
	# Force cmd.exe as shell on windows to relieve
	# Interrupt/Exception caught (code = 0xc00000fd, addr = 0x4227d3)
	# See http://superuser.com/questions/375029/make-interrupt-exception-caught
	SHELL=C:/Windows/System32/cmd.exe
	BIN=$(DIST_DIR)/$(NAME).exe
endif

# If we are running in teamcity then output the full, calculated build number
# via service message. Also, pass all go test output to the go-junit-report
# post processor
ifdef TEAMCITY_VERSION
	BANNER += "\n\#\#teamcity[buildNumber '$(VERSION)']"
	TEST_CMD += | go-junit-report > report.xml
endif

all: banner test dist

banner:
	@echo $(BANNER)

clean:
	go clean -i -x ./...
	-rm -rf $(DIST_DIR)
	-rm -rf report.xml

dist: $(BIN) $(ASSET_FILES:$(SRC_DIR)/%=$(DIST_DIR)/%)

$(BIN): $(GO_GET:%=$(GOPATH)/src/%) $(shell find . -name '$(SRC_DIR)/*.go')
	CGO_ENABLED=0 GOOS=linux godep go build \
		-ldflags "-X main.version=$(VERSION)" \
		-a \
		-installsuffix cgo \
		-o $(BIN) \
		$(SRC_DIR)/*.go

test: $(GO_GET:%=$(GOPATH)/src/%)
	$(TEST_CMD)

docker-build: test dist
	chmod +x $(BIN)
	docker build \
		-t $(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME):$(VERSION) \
		--build-arg BIN=$(BIN) \
		--build-arg DIST_DIR=$(DIST_DIR) .
	docker tag \
		-f \
		$(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME):$(VERSION) \
		$(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME):latest

docker-push:
	docker push $(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME):$(VERSION)
	docker push $(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME):latest

$(DIST_DIR)/%: $(SRC_DIR)/%
	@mkdir -p $(dir $@)
	@echo "Copying $< to $@"
	@cp $< $@

$(GOPATH)/src/%:
	go get -v $*

.PHONY: all dist clean test test-local test-teamcity docker-build docker-push
