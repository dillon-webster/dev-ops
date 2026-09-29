.PHONY: lint test build

lint:
	ruff check app

test:
	REDIS_HOST=localhost pytest app/tests

build:
	docker build -t devops-app:latest app
