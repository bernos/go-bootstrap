FROM centurylink/ca-certs

ARG DIST_DIR=./dist
ARG BIN=${DIST_DIR}/main
ENV PORT 9000

COPY ${DIST_DIR}/ /
COPY ${BIN} /main

EXPOSE 9000

ENTRYPOINT ["/main"]
