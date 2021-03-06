SHELL=/bin/bash

TESTS=$(shell go list ./... | grep -v /vendor/)

git_commit := $(shell git rev-parse --short HEAD)
git_branch := $(shell git symbolic-ref -q --short HEAD)
git_upstream := $(shell git remote get-url $(shell git config branch.$(shell git symbolic-ref -q --short HEAD).remote) 2> /dev/null)

export GIT_BRANCH = $(git_branch)
export GIT_UPSTREAM = $(git_upstream)

VERSION_LDFLAGS=\
 -X "github.com/bmeg/arachne/version.BuildDate=$(shell date)" \
 -X "github.com/bmeg/arachne/version.GitCommit=$(git_commit)" \
 -X "github.com/bmeg/arachne/version.GitBranch=$(git_branch)" \
 -X "github.com/bmeg/arachne/version.GitUpstream=$(git_upstream)"

export ARACHNE_VERSION = 0.2.0
# LAST_PR_NUMBER is used by the release notes builder to generate notes
# based on pull requests (PR) up until the last release.
export LAST_PR_NUMBER = 125

# ---------------------
# Compile and Install
# ---------------------
# Build the code
install: depends
	@touch version/version.go
	@go install -ldflags '$(VERSION_LDFLAGS)' .

# Update submodules and build code
depends:
	@git submodule update --init --recursive
	@go get github.com/golang/dep/cmd/dep
	@dep ensure

# Build the code including the rocksdb package
with-rocksdb: depends
	@go install -tags 'rocksdb' -ldflags '$(VERSION_LDFLAGS)' .

# --------------------------
# Complile Protobuf Schemas
# --------------------------
proto:
	@go get github.com/ckaznocha/protoc-gen-lint
	@cd aql && protoc \
		-I ./ \
		-I ../googleapis \
		--lint_out=. \
		--go_out=Mgoogle/protobuf/struct.proto=github.com/golang/protobuf/ptypes/struct,plugins=grpc:. \
		--grpc-gateway_out=logtostderr=true:. \
		aql.proto
	@cd kvindex && protoc \
		-I ./ \
		--go_out=. \
		index.proto

proto-depends:
	@go get github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway
	@go get github.com/golang/protobuf/protoc-gen-go
	@go get github.com/ckaznocha/protoc-gen-lint

# ---------------------
# Code Style
# ---------------------
# Automatially update code formatting
tidy:
	@for f in $$(find . -path ./vendor -prune -o -name "*.go" -print | egrep -v "\.pb\.go|\.gw\.go|underscore\.go"); do \
		gofmt -w -s $$f ;\
		goimports -w $$f ;\
	done;

# Run code style and other checks
lint:
	@go get github.com/alecthomas/gometalinter
	@gometalinter --install > /dev/null
	@gometalinter --disable-all --enable=vet --enable=golint --enable=gofmt --enable=misspell \
		--vendor \
		-e '.*bundle.go' -e ".*pb.go" -e ".*pb.gw.go" -e "underscore.go" \
		./...

# ---------------------
# Release / Snapshot
# ---------------------
snapshot: depends
	@goreleaser release \
		--rm-dist \
		--snapshot

release: depends
	@go get github.com/buchanae/github-release-notes
	@goreleaser release \
		--rm-dist \
		--release-notes <(github-release-notes -org bmeg -repo arachne -stop-at ${LAST_PR_NUMBER})

# ---------------------
# Tests
# ---------------------
test:
	@go test $(TESTS)

test-conformance:
	python conformance/run_conformance.py http://localhost:18201

# ---------------------
# Database development
# ---------------------
start-mongo:
	@docker rm -f arachne-mongodb-test > /dev/null 2>&1 || echo
	docker run -d --name arachne-mongodb-test -p 27000:27017 docker.io/mongo:3.6.4 > /dev/null

start-elastic:
	@docker rm -f arachne-es-test > /dev/null 2>&1 || echo
	docker run -d --name arachne-es-test -p 19200:9200 -p 9300:9300 -e "discovery.type=single-node" -e "xpack.security.enabled=false" docker.elastic.co/elasticsearch/elasticsearch:5.6.3 > /dev/null

start-postgres:
	@docker rm -f arachne-postgres-test > /dev/null 2>&1 || echo
	docker run -d --name arachne-postgres-test -p 15432:5432 -e POSTGRES_PASSWORD= -e POSTGRES_USER=postgres postgres:10.4 > /dev/null

start-mysql:
	@docker rm -f arachne-mysql-test > /dev/null 2>&1 || echo
	docker run -d --name arachne-mysql-test -p 13306:3306 -e MYSQL_ALLOW_EMPTY_PASSWORD=yes mysql:8.0.11 --default-authentication-plugin=mysql_native_password > /dev/null

# ---------------------
# Website
# ---------------------
website:
	hugo --source ./website

# Serve the website on localhost:1313
website-dev:
	hugo --source ./website -w server

# ---------------------
# Other
# ---------------------
.PHONY: test rocksdb website
