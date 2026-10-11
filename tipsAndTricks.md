# Tips & Tricks

## Base64

- can be done from the command line - https://superuser.com/a/120815
- python & node can also do it fairly easily - roughly 3 lines each plus any file read/write

## SSH / tmux

`tmux` can be used to keep a remote session alive when ssh is disconnected.
This is very handy for quickly and easily spining up a long-running job on a remote system.
It can also be wired in directly to an ssh command, and wrapping that command in an alias might also have nice ergonomics.

Example that either creates or connects to a session named `my_session_name`:

```shell
ssh -i ~/.ssh/id_rsa -t me@192.168.0.100 tmux new-session -A -s my_session_name
```
