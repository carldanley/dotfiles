# dotfiles

## Dependencies

1. `sudo easy_install Pygments`
1. Latest version of the Java SDK

## Customizations

For anything you don't want to be version controlled, create a `custom` folder inside of `~/dotfiles`. Then, use any of the following files to add customizations:

1. `~/dotfiles/.aliases`
1. `~/dotfiles/.imports`
1. `~/dotfiles/.functions`
1. `~/dotfiles/.exports`

## Installation

Run the following:

1. `cd ~`
1. `git clone git@github.com:carldanley/dotfiles.git`
1. `echo ". ~/dotfiles/entrypoint.sh" >> ~/.bash_profile`

## iTerm2 Colors

* Theme: [https://github.com/christianbundy/spacegrey-iterm](https://github.com/christianbundy/spacegrey-iterm)
* Font: 20pt Inconsolata
