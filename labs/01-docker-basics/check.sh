#!/usr/bin/env bash
source "$(dirname "$0")/../lib.sh"
require_docker
LAB="$REPO_ROOT/labs/01-docker-basics"

title "Lab 01: Docker basics"

check "container 'lab01-web' exists" "docker run ... --name lab01-web ..." \
  docker inspect lab01-web

check "it is running" "docker ps -a shows it? Start it with: docker start lab01-web" \
  test "$(docker inspect -f '{{.State.Running}}' lab01-web 2>/dev/null)" = "true"

check "it uses the nginx:alpine image" "docker run ... nginx:alpine" \
  test "$(docker inspect -f '{{.Config.Image}}' lab01-web 2>/dev/null)" = "nginx:alpine"

check "host port 8090 maps to container port 80" "-p 8090:80" \
  sh -c "docker port lab01-web 80 2>/dev/null | grep -q ':8090$'"

mount_src=$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/usr/share/nginx/html"}}{{.Source}}{{end}}{{end}}' lab01-web 2>/dev/null)
check "site/ is bind-mounted at /usr/share/nginx/html" "-v \"\$(pwd)/site:/usr/share/nginx/html:ro\"" \
  test "$(cd "$mount_src" 2>/dev/null && pwd -P)" = "$(cd "$LAB/site" && pwd -P)"

check "the mount is read-only" "add :ro to the end of the -v value" \
  test "$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/usr/share/nginx/html"}}{{.RW}}{{end}}{{end}}' lab01-web 2>/dev/null)" = "false"

page=$(curl -fsS http://localhost:8090 2>/dev/null)
check "http://localhost:8090 serves the page" "is the container running with the right port?" \
  grep -q "Hello, DevOps" <<<"$page"

check "you put your name in index.html" "edit site/index.html" \
  sh -c "! grep -q 'YOUR NAME HERE' '$LAB/site/index.html'"

summary
