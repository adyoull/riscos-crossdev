# The container image, and building on GitHub

From 1.8, each release of riscos-crossdev is also a container image:
`ghcr.io/adyoull/riscos-crossdev:<version>`. It has the release's toolchain
and devkit installed, and every package `make check` needs. With it you can
build RISC OS programs on any machine that runs Docker, and on GitHub.

## Using the image on your own machine

From your project's directory:

```sh
docker run --rm -v "$PWD":/src ghcr.io/adyoull/riscos-crossdev:1.8 make check all
```

- Your project is at `/src`, the working directory. riscos-crossdev is at
  `/opt/riscos-crossdev`.
- `RCD_DIR`, `RISCOS_TOOLCHAIN` and `RISCOS_DEVKIT` are set, and the
  toolchain is on `PATH`. A Makefile with `RCD_DIR ?= ...` and
  `include $(RCD_DIR)/riscos.mk` works as it is, and so does CMake with
  `-DCMAKE_TOOLCHAIN_FILE=$RCD_DIR/cmake/riscos.cmake`.
- **Files you build are owned by root** unless you run as yourself:
  `docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp -v "$PWD":/src ...`
- **For a shell:** `docker run --rm -it -v "$PWD":/src ghcr.io/adyoull/riscos-crossdev:1.8 bash`.
- The image is for x86-64. On an ARM Mac or ARM Linux machine Docker runs it
  under emulation: it works, but slowly.

Use a version number, not `:latest`, for the same reason you use a tagged
release: everyone building your project then gets the same compiler and
libraries.

## Building your port on GitHub

`ci/` has two workflows to copy into your repository's
`.github/workflows/`. Both read the riscos-crossdev version to use from a
one-line file, `.riscos-crossdev`, at the top of your repository:

```sh
echo 1.8 > .riscos-crossdev
```

1. **`ci/riscos-build.yml`** builds your project in the image on every push
   and pull request, and keeps what it makes (a zip, say) as a download on
   the run's page. Set `BUILD` to your build and test command (default
   `make check all`) and `ARTIFACTS` to what it makes.
2. **`ci/riscos-crossdev-update.yml`** looks once a week for a newer
   riscos-crossdev release. When there is one, it builds your project with
   it and opens a pull request that changes `.riscos-crossdev`, saying
   whether the build passed. It changes nothing on its own: you decide
   whether to merge.
   - It needs, in your repository's Settings > Actions > General:
     "Workflow permissions: Read and write" and "Allow GitHub Actions to
     create and approve pull requests".
   - It builds before opening the pull request because GitHub doesn't
     start workflows for a pull request that a workflow opened.

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
