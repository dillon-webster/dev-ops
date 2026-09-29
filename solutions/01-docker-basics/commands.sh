# Run from labs/01-docker-basics
docker run -d --name lab01-web -p 8090:80 -v "$(pwd)/site:/usr/share/nginx/html:ro" nginx:alpine
