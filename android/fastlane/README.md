fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android beta

```sh
[bundle exec] fastlane android beta
```

Build and upload Beta version for a region

### android internal

```sh
[bundle exec] fastlane android internal
```

Build and upload Internal version for a region

### android alpha

```sh
[bundle exec] fastlane android alpha
```

Build and upload Alpha version for a region

### android production

```sh
[bundle exec] fastlane android production
```

Build and upload Production version for a region

### android all_beta

```sh
[bundle exec] fastlane android all_beta
```

Build and upload Beta version for all regions

### android all_internal

```sh
[bundle exec] fastlane android all_internal
```

Build and upload Internal version for all regions

### android all_alpha

```sh
[bundle exec] fastlane android all_alpha
```

Build and upload Alpha version for all regions

### android all_production

```sh
[bundle exec] fastlane android all_production
```

Build and upload Production version for all regions

### android promote

```sh
[bundle exec] fastlane android promote
```

Promote an app from one track to another

### android promote_all

```sh
[bundle exec] fastlane android promote_all
```

Promote all regions from one track to another

### android build

```sh
[bundle exec] fastlane android build
```

Build the aplication for internal distribution

### android build_all

```sh
[bundle exec] fastlane android build_all
```

Build all regions

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
