package main

import (
	"fmt"
)

var (
	version string //will be set by ldflags at build time
)

func main() {
	fmt.Printf("Hello World from version %s", version)
}
