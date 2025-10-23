## 🧩 1️⃣ Overview — what happens when you log in

When you log into a shell (via `login`, `getty`, or SSH):

1. The shell starts in **login mode** → executes `/etc/profile`
2. Then it runs:

   * `$HOME/.profile` (for Bourne / sh)
   * or `$HOME/.bash_profile` and `$HOME/.bashrc` (for Bash, if available)
3. `/etc/profile` may also source scripts from `/etc/profile.d/`

So the flow looks like:

```
/etc/profile
 ├── /etc/profile.d/*.sh
 └── ~/.profile  (or ~/.bash_profile → ~/.bashrc)
```

That means any global customization for *all users* goes into `/etc/profile` or `/etc/profile.d/*.sh`.

---

## ⚙️ 2️⃣ Customizing `/etc/profile`

Create or edit `/etc/profile` in your rootfs:

```bash
#!/bin/sh
# /etc/profile - global shell configuration

# Set PATH
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export PATH

# Set prompt (PS1)
# \u = user, \h = hostname, \w = current directory
PS1='\[\033[1;32m\]\u@\h\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]\$ '

# Set environment variables
export HISTFILE=/var/log/.ash_history
export HISTSIZE=200
export EDITOR=vi
export PAGER=less
export LANG=C.UTF-8

# Message of the day
echo "========================================="
echo "   Welcome to Magdi Minimal Linux 🧠"
echo "   $(uname -sr)"
echo "========================================="

# Load additional scripts
for script in /etc/profile.d/*.sh ; do
    [ -r "$script" ] && . "$script"
done
```

**Explanation**

* `PS1` controls your shell prompt appearance.
* `\[\033[1;32m\]` and `\[\033[0m\]` control ANSI colors (green user, blue path).
* The `for script in /etc/profile.d/*.sh` loop automatically loads plugin-like scripts.

---

## 🧩 3️⃣ Add-ons in `/etc/profile.d/`

You can modularize your environment by placing `.sh` scripts here.
They are all sourced at login.

### Example 1 — `/etc/profile.d/alias.sh`

```bash
#!/bin/sh
# Common command aliases

alias ll='ls -alF --color=auto'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
```

### Example 2 — `/etc/profile.d/autocompletion.sh`

If you install `bash-completion` or have a minimal completion script:

```bash
#!/bin/sh
# Enable command completion if available

if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi
```

### Example 3 — `/etc/profile.d/prompt.sh`

To dynamically change the prompt:

```bash
#!/bin/sh
# Fancy dynamic PS1

if [ "$(id -u)" -eq 0 ]; then
    PS1='\[\033[1;31m\]\u@\h\[\033[0m\]:\w# '
else
    PS1='\[\033[1;32m\]\u@\h\[\033[0m\]:\w$ '
fi
```

### Example 4 — `/etc/profile.d/banner.sh`

```bash
#!/bin/sh
echo "Welcome $(whoami)! The system uptime is: $(uptime -p)"
```

---

## 🧩 4️⃣ PS1 deep customization cheat sheet

You can make your shell look exactly as you want:

| Escape | Meaning                               | Example            |
| ------ | ------------------------------------- | ------------------ |
| `\u`   | Username                              | `root`             |
| `\h`   | Hostname (short)                      | `magdi`            |
| `\H`   | Full hostname                         | `magdi.local`      |
| `\w`   | Current working directory             | `/home/root`       |
| `\W`   | Basename of current directory         | `root`             |
| `\t`   | Current time (HH:MM:SS)               | `12:03:45`         |
| `\d`   | Date                                  | `Tue Oct 22`       |
| `\#`   | Command number                        | `42`               |
| `\$`   | Shows `#` if root, `$` if normal user | useful for clarity |

Example:

```bash
PS1='\[\033[1;33m\]\u@\h\[\033[0m\] \[\033[1;34m\]\w\[\033[0m\]\n\$ '
```

→ gives a two-line colorful prompt:

```
root@magdi /etc/init.d
#
```

---

## 🧩 5️⃣ Make changes apply to all shells

* For **BusyBox ash/sh** → `/etc/profile` + `/etc/profile.d/*.sh` are sourced automatically for login shells.
* For **Bash** → same behavior, plus `~/.bashrc` for interactive shells.
* For **non-login shells** (e.g. scripts run via systemd), use `export` inside `/etc/environment` or add your own `/etc/profile` sourcing in `/bin/sh` symlink.

---

## 🧩 6️⃣ Optional: `/etc/motd` (message of the day)

Add a static message:

```
Welcome to Magdi Minimal Linux (v0.1)
Enjoy your minimal rootfs 😎
```

If your BusyBox `login` was compiled with `CONFIG_FEATURE_MOTD`, this is automatically printed on login.

---

## 🧩 7️⃣ Example full tree

```
/etc/
├── motd
├── profile
└── profile.d/
    ├── alias.sh
    ├── autocompletion.sh
    ├── prompt.sh
    └── banner.sh
```

---

## 🧠 Pro Tip — quick testing

You can re-source `/etc/profile` any time:

```bash
. /etc/profile
```

or check what `PS1` is currently set to:

```bash
echo $PS1
```

---

## ⚙️ Optional advanced: `/etc/environment`

Unlike `/etc/profile`, this file doesn’t use shell syntax.
It’s a simple `KEY=VALUE` list for non-interactive processes.

Example:

```
PATH="/usr/local/bin:/usr/bin:/bin"
LANG="C.UTF-8"
EDITOR="vi"
```

---

## ✅ Summary

| Task                  | File                        | Example                   |
| --------------------- | --------------------------- | ------------------------- |
| Global environment    | `/etc/profile`              | PATH, LANG, PS1           |
| Modular configs       | `/etc/profile.d/*.sh`       | aliases, colors, messages |
| Per-user settings     | `~/.profile` or `~/.bashrc` | personal PS1, aliases     |
| Non-shell environment | `/etc/environment`          | variables for daemons     |
| Login message         | `/etc/motd`                 | static banner             |

