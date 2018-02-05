#!/bin/bash

# source the exports first
. ~/dotfiles/base/.exports

if [ -f ~/dotfiles/custom/.exports ] ; then
  . ~/dotfiles/custom/.exports
fi

# source the imports next
. ~/dotfiles/base/.imports

if [ -f ~/dotfiles/custom/.imports ] ; then
  . ~/dotfiles/custom/.imports
fi

# source the aliases next
. ~/dotfiles/base/.aliases

if [ -f ~/dotfiles/custom/.aliases ] ; then
  . ~/dotfiles/custom/.aliases
fi

# source the functions last
. ~/dotfiles/base/.functions

if [ -f ~/dotfiles/custom/.functions ] ; then
  . ~/dotfiles/custom/.functions
fi

# register the global gitignore commands
git config --global core.excludesfile ~/dotfiles/.gitignore

# make sure nvm directory exists
if [ ! -d ~/.nvm ] ; then
  mkdir ~/.nvm
fi
