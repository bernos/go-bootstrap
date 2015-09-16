# Name of the binary to produce
NAME=changeme

# Output dir
OUTPUT_DIR=./dist

# Path to build artifact
OUTPUT=$(OUTPUT_DIR)/$(NAME)

ifeq ($(OS),Windows_NT)
	# Force cmd.exe as shell on windows to relieve
	# Interrupt/Exception caught (code = 0xc00000fd, addr = 0x4227d3)
	# See http://superuser.com/questions/375029/make-interrupt-exception-caught
	SHELL=C:/Windows/System32/cmd.exe
	OUTPUT=$(OUTPUT_DIR)/$(NAME).exe
endif

all: compile

clean:
	go clean -i -x ./...
	-rm -rf $(OUTPUT_DIR)

deps:
	go get -v github.com/tools/godep && \
	$(GOPATH)/bin/godep save ./...
	$(GOPATH)/bin/godep restore ./...

test: deps
	$(GOPATH)/bin/godep go test -v ./...

compile: test
	$(GOPATH)/bin/godep go build -o $(OUTPUT)

run: all
	$(OUTPUT)

.PHONY: all clean deps test compile run
