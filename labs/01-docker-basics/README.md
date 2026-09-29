# Lab 01: Docker basics

**Time:** ~30 min · **You'll learn:** images vs containers, ports, bind mounts, logs, exec

## The idea

- An **image** is a packaged filesystem plus a default command, like `nginx:alpine`. It's read-only, a bit like a template.
- A **container** is a running (or stopped) instance of an image. You can run many containers from one image.
- Containers are isolated. To reach one from your Mac you **publish a port** (`-p HOST:CONTAINER`).
- A **bind mount** (`-v /path/on/mac:/path/in/container`) makes a folder on your Mac show up inside the container. Edit a file on your Mac and the container sees the change right away.

## Warm-up (not graded, just type these and read the output)

```bash
docker run hello-world              # pulls an image, runs it, exits
docker ps                           # running containers (hello-world already exited)
docker ps -a                        # ALL containers, including stopped ones
docker images                       # images you have locally
docker run --rm -it alpine sh       # a shell inside a tiny Linux. Try `ls /`, `cat /etc/os-release`, then `exit`
```

`--rm` deletes the container when it exits. `-it` gives you an interactive terminal.

## Your task

Run a web server that serves the page in `site/index.html`.

1. Edit `site/index.html` and put your name in it where it says `YOUR NAME HERE`.
2. Start a container with these properties:
   - named `lab01-web`
   - from the image `nginx:alpine`
   - running in the background (detached)
   - port **8090** on your Mac goes to port **80** in the container
   - this lab's `site/` folder is mounted at `/usr/share/nginx/html`, read-only
3. Open http://localhost:8090 in your browser and check that you see your page.
4. Explore (not graded, but this is the useful part):
   - `docker logs lab01-web`: reload the page and run it again. What changed?
   - `docker logs -f lab01-web` follows the logs live (Ctrl-C to stop following).
   - `docker exec -it lab01-web sh` gets a shell *inside* the running container. Run `ls /usr/share/nginx/html`.
   - Edit `index.html` on your Mac and refresh the browser. No restart needed. Why?
   - `docker stop lab01-web`, then `docker ps` and `docker ps -a`. Then `docker start lab01-web`.

Check your work:

```bash
./check.sh
```

## Hints

<details><summary>Which flags do I need?</summary>

`docker run --help` lists them all. You need `-d`, `--name`, `-p`, and `-v`. To make a mount read-only, add `:ro` to the end of the `-v` value.
</details>

<details><summary>The mount path needs to be absolute</summary>

`-v site:/usr/...` makes a *named volume* called "site", which isn't what you want. Use `"$(pwd)/site"` to get the full path of the folder.
</details>

<details><summary>"container name already in use"</summary>

A container named `lab01-web` already exists, possibly a stopped one. Remove it with `docker rm -f lab01-web` and try again.
</details>

## Clean up (when you're done)

```bash
docker rm -f lab01-web
```
