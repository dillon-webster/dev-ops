# Lab 06: fill in these targets. CI will call them, so CI runs exactly what you run locally.
.PHONY: lint test build

lint:
	@echo "TODO: run ruff on app/" && exit 1

test:
	@echo "TODO: run pytest on app/tests" && exit 1

build:
	@echo "TODO: docker build the app image as devops-app:latest" && exit 1
