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

## GPG Keys

### Generating a new key

To generate a new key, type: `gpg --full-gen-key` (alias: `gpgcreate`).

At the prompt, select the following:

1. type `4` for `(4) RSA (sign only)`
1. keysize: `4096`
1. expiration: choose something reasonable

To confirm the key was created, type: `gpg --list-secret-keys --keyid-format SHORT` (alias: `gpglist`)

### Restarting gpg-agent

If your GPG agent is having issues, you can restart it with:

```sh
gpgconf --kill gpg-agent
gpgconf --launch gpg-agent
```

^ (alias: `gpgrestart`)

### Adding multiple emails

You can add multiple email addresses by doing the following:

1. Edit the key: `gpg --edit-key 674CB45A` (alias: `gpgedit 674CB45A`)
1. In gpg prompt, type `adduid`; follow the prompts
1. Then, update the trust for the new identity: `uid 2` and `trust`; type `5` (for "I trust ultimately")
1. Type `save`

### Exporting GPG key

To export the GPG key for use with something like GitHub or GitLab, type: `gpg --armor --export 674CB45A` (alias: `gpgexport 674CB45A`)
