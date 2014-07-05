# A Package Loader

A simple package loader to attempt to load slow packages in the background.

## Settings

* `automaticallyAddSlowLoadingPackages` Turn on/off automatically adding packages that take over longer than `slowLoadingPackageThreshold` milliseconds to load.
* `delayBeforeStarting` The delay in milliseconds before beginning to load slow packages after this package is loaded.
* `delayBetweenPackages` The delay in milliseconds between loading each slow package. This prevents freezing the UI during load.
* `ignorePackageNames` A list of packages that will never be considered slow loading, and thus are always loaded before the window is shown.
* `deferredLoadingPackageNames` A list of packages that will be loaded in the background. This is automatically populated if `automaticallyAddSlowLoadingPackages` is true.
* `slowLoadingPackageThreshold` Maximum time in milliseconds a package can take before being considered slow.

## How It Works

This package works by attempting to be the first package to load (which is why it starts with "a"). We can then insert dummy packages into the package manager to skip loading the real package. This is due to this check [`return pack if pack = @getLoadedPackage(name)`](https://github.com/atom/atom/blob/v0.106.0/src/package-manager.coffee#L152) in `packageManager.loadPackage()`.

We then do a fixed delay `setTimeout(..., 1500)`. We used a fixed delay as calling `atom.getCurrentWindow()` + `atom.getCurrentWindow().isLoading()` is very slow (can take up to 100ms). This value can be changed in the config.

After loading a package, we then wait a bit (default: `25ms`) in order for the UI loop to iterate. This prevents the UI from completely freezing. The UI might freeze if a single package takes forever.

Once completely loaded, we sweep the package load+activation times to see if they are considered slow (default: `loadTime + activationTime > 30ms`).

## TODO

* If a slow loading package errors, reattempt loading it again at the end.
