# Dotfiles

## Secrets

In order for chezmoi to run properly run with my dotfiles, you will need to:

### Setup the environment variables

First, create a new file in `$HOME/.config/env/` called `bitwarden-session.env`.

Copy the following contents in this file:

```sh
#!/usr/bin/env bash
export BW_CLIENTID=""
export BW_CLIENTSECRET=""
export BW_SESSION=""
```

### Setup the base server

Since vaultwarden is self-hosted, run the following command:

```
bw config server "https://my-bitwarden-instance.com"
```

### Unlock the vault

In order to create a bitwarden session, perform the following commands:

```
$ bw login --apikey
$ bw unlock
```

You should receive an `export BW_SESSION` message from the `bw unlock` command; add the `export ...` portion to the `$HOME/.config/env/bitwarden-session.env` file (which will be loaded by ZSH).

Finally, reload your shell
