- `/etc` is now set up as overlayfs with the original `/etc` folder being the store for changed files/directories and `/usr/share/flatcar/etc` providing the lower default directory tree ([bootengine#53](https://github.com/flatcar/bootengine/pull/53), [scripts#666](https://github.com/flatcar/scripts/pull/666))