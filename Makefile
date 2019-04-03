
.PHONY: build install

.DEFAULT_GOAL := help

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

# If the first argument is one of the supported commands...
SUPPORTED_COMMANDS := npm
SUPPORTS_MAKE_ARGS := $(findstring $(firstword $(MAKECMDGOALS)), $(SUPPORTED_COMMANDS))
ifneq "$(SUPPORTS_MAKE_ARGS)" ""
    # use the rest as arguments for the command
    COMMAND_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
    # ...and turn them into do-nothing targets
    $(eval $(COMMAND_ARGS):;@:)
endif

install: ## install depedencies thanks to a dockerized npm install
	@docker run -it --rm -v $$(pwd):/app -w /app --net=host -e NODE_ENV -e http_proxy -e https_proxy node:4.4.0 npm install -q
	@make chown

build: ## build the docker istex/istex-view image locally
	@docker build -t istex/istex-view:2.5.2 --build-arg http_proxy --build-arg https_proxy .

run-prod: ## run istex-view in production mode
	@echo 'module.exports = {};' > ./www/src/config.local.js
	@docker-compose -f ./docker-compose.yml up -d
	@tail -f -n 0 ./logs/*.log

run-debug: ## run istex-view in debug mode (live regenerate the bundle.js if js are modified on fs)
	@echo 'module.exports = { istexArkUrl: "http://127.0.0.1:3000" };' > ./www/src/config.local.js
	@docker-compose -f ./docker-compose.debug.yml up -d
	@# attach to the istex-view-www container in order to be able to stop it easily with CTRL+C
	@docker attach istex-view-www

# makefile rule used to keep current user's unix rights on the docker mounted files
chown:
	@test ! -d $$(pwd)/node_modules || docker run -it --rm --net=host -v $$(pwd):/app node:4.4.0 chown -R $$(id -u):$$(id -g) /app/

npm: ## npm wrapper. example: make npm install --save mongodb-querystring
	@docker run -it --rm -v $$(pwd):/app -w /app --net=host -e NODE_ENV -e http_proxy -e https_proxy node:4.4.0 npm $(filter-out $@,$(MAKECMDGOALS))
	@make chown

lint: ## checks the coding rules (in a dockerized process)
	@docker run -it --rm -v $$(pwd):/app -w /app -e NODE_ENV -e http_proxy -e https_proxy node:4.4.0 npm run lint