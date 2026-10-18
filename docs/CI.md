# The container image, and building on GitHub

From 1.8, each release of riscos-crossdev is also a container image:
`ghcr.io/adyoull/riscos-crossdev:<version>`. It has the release's toolchain
and devkit installed, and every package `make check` needs. With it you can
build RISC OS programs on any machine that runs Docker, and on GitHub.

## Using the image on your own machine

From your project's directory:

```sh
docker run --rm -v "$PWD":/src ghcr.io/adyoull/riscos-crossdev:1.8.2 make check all
```

- Your project is at `/src`, the working directory. riscos-crossdev is at
  `/opt/riscos-crossdev`.
- `RCD_DIR`, `RISCOS_TOOLCHAIN` and `RISCOS_DEVKIT` are set, and the
  toolchain is on `PATH`. A Makefile with `RCD_DIR ?= ...` and
  `include $(RCD_DIR)/riscos.mk` works as it is, and so does CMake with
  `-DCMAKE_TOOLCHAIN_FILE=$RCD_DIR/cmake/riscos.cmake`.
- **Files you build are owned by root** unless you run as yourself:
  `docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp -v "$PWD":/src ...`
- **For a shell:** `docker run --rm -it -v "$PWD":/src ghcr.io/adyoull/riscos-crossdev:1.8.2 bash`.
- The image is for x86-64. On an ARM Mac or ARM Linux machine Docker runs it
  under emulation: it works, but slowly.

Use a version number, not `:latest`, for the same reason you use a tagged
release: everyone building your project then gets the same compiler and
libraries.

## Building your port on GitHub

`ci/` has two workflows to copy into your repository's
`.github/workflows/`. Both read `.riscos-deps`, a file at the top of your
repository that names, one per line, the releases of the owner's other
repositories your project is built with:

```
# NAME TAG: repositories at github.com/adyoull, at a release tag
riscos-crossdev v1.8.2
riscos-mesa v20.3.5-16
riscos-ffmpeg v5.1.10-riscos22
```

The `riscos-crossdev` line also chooses the container image
(`ghcr.io/adyoull/riscos-crossdev:1.8.2`). For a repository of another
owner, write `OWNER/NAME`.

1. **`ci/riscos-build.yml`** builds your project in the image on every push
   and pull request, and keeps what it makes (a zip, say) as a download on
   the run's page. Set `BUILD` to your build and test command (default
   `make check all`) and `ARTIFACTS` to what it makes.
   - **`PACKAGES`:** Ubuntu packages your build needs that the image
     hasn't, such as `"python3-pil shared-mime-info"`. They're installed
     before the build. Set the same in both workflows.
   - The image has what the kit itself uses, and what several ports share
     (meson, g++ for ARM Linux; `docker/Dockerfile` lists it all). A
     package only one port needs goes in that port's `PACKAGES`, so the
     image doesn't grow with every port. If several ports come to need
     one, ask for it to be added to the image.
2. **`ci/riscos-deps-update.yml`** checks every day whether any of those
   repositories has a newer release. When one has, it moves the pin, builds
   your project with it, and opens a pull request listing what changed and
   whether the build passed. It changes nothing on its own: you decide
   whether to merge.
   - If your build also pins a dependency elsewhere (a checksum file,
     `build/env.sh`), add an executable `ci/riscos-deps-hook.sh`. It's run
     as `ci/riscos-deps-hook.sh NAME OLD_TAG NEW_TAG` to update those files
     too. riscos-crossdev's own `toolchain/deps-hook.sh` is an example.
   - It needs, in your repository's Settings > Actions > General:
     "Workflow permissions: Read and write" and "Allow GitHub Actions to
     create and approve pull requests".
   - It builds before opening the pull request because GitHub doesn't
     start workflows for a pull request that a workflow opened.
   - It only sees **releases** marked as the latest on GitHub. Mark test
     builds and release candidates as pre-releases, and they're left alone.

## How the repositories feed each other

Each repository watches the releases of the ones it's built with. So a
change moves down the chain one release at a time, and you approve each
step:

1. riscos-unixlib or riscos-mesa makes a release.
2. The next day, riscos-crossdev's own workflow
   (`.github/workflows/update-deps.yml`) opens a pull request moving
   `devkit/DEVKIT` or `toolchain/SOURCES` to it, built and checked. You
   merge it and release riscos-crossdev. A new UnixLib also needs a new
   toolchain tarball (`make dist`).
3. The day after, every port whose `.riscos-deps` names riscos-crossdev
   (or riscos-mesa) gets a pull request, built with the new release.
4. You merge, test on a Pi, and release the ports you want to. Releasing,
   say, riscos-ffmpeg's devkit then reaches the repositories built on it,
   such as Matinee, the same way.

Nothing moves on unless you release, so you decide how far a change goes.

## What this doesn't do

- **It doesn't release anything.** A build that passes on Linux hasn't run
  on RISC OS. Merge the update, test on a Pi, then tag a release yourself.
- **It doesn't test on RISC OS.** The checks, the Fake RISC OS and QEMU run
  in the image; the Pi is still yours to test on (PI-TESTING.md).

## How the image is made

- `docker/Dockerfile` builds it from Ubuntu 24.04, the packages in
  SETUP.md, and this release's checksummed toolchain and devkit.
- `.github/workflows/docker.yml` runs for each release tag:
  1. it builds the image;
  2. runs `make check` inside it;
  3. builds `examples/wimp` from outside the kit, as a port would;
  4. only then publishes the image.

  Run the workflow by hand from the Actions tab to build the image of a
  release again.
- To build it yourself: `docker build -f docker/Dockerfile -t riscos-crossdev .`
  from the top of the repository.
