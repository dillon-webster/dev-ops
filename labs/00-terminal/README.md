# Lab 00: Terminal detective

**Time:** 1–2 hours · **You'll learn:** `ls`, `cd`, `cat`, `less`, `head`, `tail`, `wc`, `grep`, `find`, `sort`, `uniq`, `awk`, and pipes (`|`)

## The situation

It's Monday. Over the weekend something went wrong in production, and all you have is a folder of logs and config files in `data/`. Your job is to answer questions about what happened, **using only the terminal**. Don't open these files in an editor. That's the whole point.

```
data/
├── nginx/access.log        ← every web request (one per line)
├── app/{api,billing,worker}/*.log   ← application logs
└── config/{dev,staging,prod}/*.conf ← configuration files
```

Start here:

```bash
cd ~/Code/devops-practice/labs/00-terminal/data
```

---

## Crash course

Read this once, then use it as a reference while you work.

### Moving around and looking at files

| Command | What it does |
|---|---|
| `pwd` | Print the folder you're in |
| `ls`, `ls -la` | List files. `-l` is the long format, `-a` includes hidden files |
| `cd app/billing`, `cd ..`, `cd -` | Go into a folder, go up one, go back to the previous folder |
| `cat file` | Print the whole file |
| `less file` | Scroll through a big file. `space`/`b` = page down/up, `/word` = search, `n` = next match, `q` = quit |
| `head -n 5 file` | The first 5 lines |
| `tail -n 5 file` | The last 5 lines |
| `tail -f file` | Keep watching a file as new lines are added (you'll use this on real servers constantly) |
| `wc -l file` | Count lines |
| `man grep` | The manual for any command. `q` quits |

### grep: find lines that match

`grep PATTERN file` prints every line that contains PATTERN.

| Flag | Meaning | Example |
|---|---|---|
| `-i` | ignore case | `grep -i error app.log` matches ERROR, Error, error |
| `-c` | count matching lines instead of printing them | `grep -c 404 access.log` |
| `-v` | invert: lines that *don't* match | `grep -v health access.log` |
| `-r` | recursive: search every file in a folder | `grep -r timeout app/` |
| `-l` | print only the *names* of files that match | `grep -rl timeout app/` |
| `-n` | show line numbers | `grep -n port config/prod/db.conf` |
| `-A 2` / `-B 2` | also show 2 lines After / Before each match | `grep -B 2 OutOfMemory ...` |
| `-E` | extended regex, so you can use `a\|b` as `a|b` | `grep -E 'WARN\|ERROR'` |

**Watch out for this one.** `grep 500 access.log` also matches a response *size* of 1500, or a timestamp containing `500`. Make your pattern specific. In this log the status code always comes right after the closing quote of the request, so `grep '" 500 '` only matches the status code.

A `^` means "start of line" and `$` means "end of line": `grep '^max' file` only matches lines that *start* with `max`.

### Pipes: the superpower

`|` sends the output of one command into the next one. You build answers by chaining small tools together:

```bash
grep ERROR app.log | wc -l          # how many ERROR lines?
grep ERROR app.log | head -n 3      # just show me the first few
```

### Slicing and counting

| Command | What it does |
|---|---|
| `awk '{print $1}'` | Print the 1st space-separated column of each line (`$7` = 7th, `$NF` = last) |
| `cut -d',' -f2` | Print the 2nd field, split on commas |
| `sort` | Sort lines alphabetically. `sort -n` sorts numerically, `sort -rn` numerically with biggest first |
| `uniq -c` | Collapse *adjacent* duplicate lines and count them. **Only works on sorted input**, so always `sort` first |

This is the most useful one-liner in DevOps. Memorize its shape:

```bash
... | awk '{print $1}' | sort | uniq -c | sort -rn | head
#      pick a column     group  count     biggest first  top 10
```

### find: find *files* (grep finds *lines*)

```bash
find . -name '*.conf'           # every .conf file under the current folder
find . -type d                  # every directory
find . -name '*.log' | wc -l    # how many .log files?
```

Quote the pattern (`'*.log'`). If you don't, the shell expands `*` itself before `find` ever sees it.

---

## The questions

Write your answers in `answers.txt` (one folder up from `data/`). After each answer, add the command you used after a `#`, so future-you remembers how you did it:

```
2: 999   # grep -c 'something' nginx/access.log
```

### Warm-up
1. How many requests (lines) are in `nginx/access.log`?
2. How many requests got a **500** (server error) status code?
3. Kubernetes health checks (user agent `kube-probe`) are noise. How many requests are **not** from `kube-probe`?

### Pipes
4. Ignoring `kube-probe`, which **IP address** made the most requests? (Suspicious…)
5. Which URL **path** returned the most **404**s? (What is that bot looking for?)
6. What was the path of the **very last** request in the log?

### Finding things
7. How many files ending in exactly `.log` are there under `app/` (all subfolders)?
8. Somewhere in the app logs, a service ran out of memory (`OutOfMemoryError`). What is the **file name**?
9. How many **error**-level lines are there across *all* app logs? Careful: one service logs its levels in lowercase. Count those too, but don't count lines that just *mention* the word "error" somewhere else.

### Config spelunking
10. What is `max_connections` set to in the **prod** database config? (Read the file. There's a trap.)
11. Someone committed a secret token to a config file. What is the **file name**?
12. **Bonus:** Which hour of the day (00–23) had the most requests in `access.log`?

Check your answers:

```bash
cd ..          # back to labs/00-terminal
./check.sh
```

It tells you which answers are right without revealing the correct ones.

---

## Hints

<details><summary>Q2: my count seems too high</summary>

`grep -c 500` also matches sizes like `1500` and timestamps. Use the quote trick from the crash course: `grep -c '" 500 '`.
</details>

<details><summary>Q4 / Q5: I don't know which column is which</summary>

Run `head -n 1 nginx/access.log | awk '{print $1}'`, then `$2`, then `$3`… until you find the column you want. For Q5, filter to 404s first, then pick the path column, then do the sort/uniq/sort dance.
</details>

<details><summary>Q7: I got 10, not the answer</summary>

One file is named `something.log.gz.txt`. Does it end in `.log`? What does your `-name` pattern match?
</details>

<details><summary>Q9: how do I only match the level?</summary>

In these logs the level looks like `[ERROR]`, including the brackets. In grep, `[` has a special meaning, so escape it: `'\[error\]'`. Combine that with `-r` and `-i`, then count. If you use `-c` together with `-r`, you get one count *per file*. Piping into `wc -l` gives you one total instead.
</details>

<details><summary>Q10: which line?</summary>

`grep -n max_connections config/prod/db.conf`. Lines starting with `#` are comments and are ignored by the program. Try `grep '^max_connections'`.
</details>

<details><summary>Q12: getting the hour</summary>

A timestamp looks like `[14/Sep/2026:01:23:45`. `awk '{print $4}'` gets that whole chunk. From there you can use `cut -d: -f2` to split on colons and take the 2nd piece. Then sort/uniq/sort.
</details>

## Stretch goals (not graded)

- `grep -rn 'connection refused' data/app | less`: which service keeps failing to reach the database? When did it start?
- Count requests **per status code** in one command.
- Which service has the most WARN lines?
- Try `history | grep grep` to see all the grep commands you ran.
- Make an alias: add `alias ll='ls -la'` to `~/.zshrc`, then run `source ~/.zshrc`.
