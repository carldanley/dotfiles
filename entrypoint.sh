# source the base scripts
. ~/dotfiles/base/.exports
. ~/dotfiles/base/.imports
. ~/dotfiles/base/.aliases
. ~/dotfiles/base/.functions

# source the custom scripts
if [ ~/dotfiles/custom/.exports ] ; then
  . ~/dotfiles/custom/.exports
fi
if [ ~/dotfiles/custom/.imports ] ; then
  . ~/dotfiles/custom/.imports
fi
if [ ~/dotfiles/custom/.aliases ] ; then
  . ~/dotfiles/custom/.aliases
fi
if [ ~/dotfiles/custom/.functions ] ; then
  . ~/dotfiles/custom/.functions
fi
