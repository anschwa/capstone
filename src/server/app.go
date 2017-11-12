// Senior Capstone
// Adam Schwartz Fall 2017
//
// Extraordinarily simple web server in Go
// ./app --name=<server name> --lambda=<Poisson lambda> --addr=<IP address> --port=<port>
// ./app -h for help

package main

import (
	"flag"
	"fmt"
	"log"
	"time"
	"math"
	"math/rand"
	"net/http"
)

type pageHandler struct {
	Name string
	Lambda float64
}

// Use Knuth's algorithm for generating Poisson random numbers (Wikipedia)
func poisson(lam float64) int {
	L := math.Exp(-lam)
	k := 0
	p := 1.0

	for p > L {
		k += 1
		p *= rand.Float64()
	}

	return k - 1
}

// HTTP Handler Interface
func (p pageHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// sleep to simulate server load (approximately 0-500ms)
	t := 100 * poisson(p.Lambda)
	time.Sleep(time.Duration(t) * time.Millisecond)

	fmt.Fprintf(w, "<h1>Server: %s</h1><h2>Sleep: %dms</h2>", p.Name, t)
}

// Establish routes and start server
func main() {
	// Process command line arguments
	namePtr := flag.String("name", "A", "Server name")
	addrPtr := flag.String("addr", "127.0.0.1", "IP address")
	portPtr := flag.Int("port", 8081, "port for webserver")
	lamdPtr := flag.Float64("lambda", 0.99, "lambda for Poisson distribution")
	flag.Parse()

	// Seed random number generation
	rand.Seed(time.Now().UnixNano())

	// Routing
	http.Handle("/", pageHandler{Name: *namePtr, Lambda: *lamdPtr})

	// Static Resources
	sf := http.FileServer(http.Dir("static"))
	http.Handle("/static/", http.StripPrefix("/static/", sf))

	port := fmt.Sprintf("%s:%d", *addrPtr, *portPtr)
	log.Fatalln("ListenAndServe:", http.ListenAndServe(port, nil))
}
