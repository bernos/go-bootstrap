FROM golang:1.5

COPY . /go/src/app
WORKDIR /go/src/app
RUN make docker-install 

CMD ["app"]