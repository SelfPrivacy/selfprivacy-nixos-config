# SelfPrivacy NixOS configuration

This configuration is not self-contained, as it needs to be plugged as an input of a top-level NixOS configuration flake (i.e. https://git.selfprivacy.org/SelfPrivacy/selfprivacy-nixos-template/). This flake outputs the following function:
```nix
nixosConfigurations-fun =
  { hardware-configuration # hardware-configuration.nix file
  , deployment             # deployment.nix file
  , userdata               # nix attrset, obtained by fromJSON from userdata.json
  , top-level-flake        # `self`-reference of the top-level flake
  , sp-modules             # flake inputs of sp-modules flake
  }:
```
which returns one or more attributes, containing NixOS configurations (created with `nixpkgs.lib.nixosSystem`). (As of 2024-01-10 there is only a single configuration named `default`.)

## updating flake inputs

We have 2 flake inputs:
- nixpkgs
- selfprivacy-api

Both get updated the same ways.

There are 2 methods:
1. specify input name only in a command, relying on URL inside `flake.nix`
2. specify input name and URL in a command, **overriding** whatever URL is inside `flake.nix` for the input to update (override)

In any case a Nix flake input is specified using some special _references_ syntax, including URLs, revisions, etc, described in manual: https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-flake.html#examples. Such reference can be used inside `flake.nix` or as an argument to `nix flake` commands. When a new reference is encountered Nix downloads and extracts it to /nix/store.

Before and after running `nix flake lock` (or `nix flake update`) commands you would most likely want to list current inputs using `nix flake metadata`, which are read from `flake.lock` file. Although, Nix should also print a diff between changed references once changed.

`--commit-lock-file` option tells Nix commands to do `git commit flake.lock` automatically, creating a new commit for you.

### method 1: update specific input

Example:
```console
$ nix flake lock --update-input nixpkgs
$ nix flake lock --update-input selfprivacy-api
```

Depending on how "precise" the URL was speficied in `flake.nix`, with _unmodified_ `flake.nix` the result might be:
* URL with `rev` (sha1) parameter => nothing will update (as we're already at exact commit)
* URL with `ref` (branch) parameter => input will update to the latest commit of the specified branch
* URL without `rev` nor `ref` => input will update to the latest commit of a default branch!

---

Once Nix 2.19 stabilizes, a different command _must_ be used for updating a single input (recursively), like this:
```console
$ nix flake update nixpkgs
```


### method 2: override specific input

Overriding is more powerful (for non-nested flakes) as it allows to change a flake input reference to anything just in one command (not only update in the bounds of a branch or a repository).

Example:
```console
$ nix flake lock --override-input nixpkgs github:nixos/nixpkgs?ref=nixos-24.05
$ nix flake lock --override-input selfprivacy-api git+https://git.selfprivacy.org/SelfPrivacy/selfprivacy-rest-api.git?ref=flakes
```

Similarly to update mechanism (described above), depending on the "precision" of an URL, its update scope varies accordingly.

Note, that subsequent calls of `nix flake lock --update-input <INPUT>` or `nix flake update` (or `nix flake update INPUT` by Nix 2.19+) will update the input regardless of the prior override. The information about override is stored only in `flake.lock` (`flake.nix` is not altered by Nix).

---

Note, that override does not update flake inputs recursively (say, you have a flake nested inside your flake input). For recursive updates only `nix flake lock --update-input` and `nix flake update` mechanisms are suitable. However, as of 2024-01-10 none of the SP NixOS configuration inputs contain other flakes, hence override mechanism is fine (don't confuse with top-level flake which has nested inputs).

## Updating other repositories

After changing the `flakes` branch here, you have to modify other repositories, so the new servers start up with the latest version of this config.

### NixOS template

On [selfprivacy-nixos-template](https://git.selfprivacy.org/SelfPrivacy/selfprivacy-nixos-template) run the following command:

```bash
nix flake update --override-input selfprivacy-nixos-config git+https://git.selfprivacy.org/SelfPrivacy/selfprivacy-nixos-config.git?ref=flakes
./.switch-selfprivacy-nixos-config-url git+https://git.selfprivacy.org/SelfPrivacy/selfprivacy-nixos-config.git?ref=flakes
```

And push the changes. Take note of the commit hash.

If you added a new SelfPrivacy module, you have to add it to the `sp-modules` input in `flake.nix` and update the `userdata.json` template.

### NixOS infect

On [selfprivacy-nixos-infect](https://git.selfprivacy.org/SelfPrivacy/selfprivacy-nixos-infect) modify the commit hash on this line:

```bash
readonly CONFIG_URL="https://git.selfprivacy.org/api/v1/repos/SelfPrivacy/selfprivacy-nixos-template/archive/HASH.tar.gz"
```

If you added a new SelfPrivacy module, you have to also edit a `genUserdata` function in `nixos-infect` to set up the new module.

## How to apply a change (e.g. CVE fix) to nixpkgs

### if you can determine which nixpkgs package is affected

- without building from source _(after nixpkgs binary cache is ready)_ - it will use all dependencies from the nixpkgs commit, where the patch is committed:

    1. Find a nixpkgs commit, which contains the patched files. It doesn't have to be (but it can be) the commit where the actual patch was introduced, it can be a more recent commit.
    2. In [`overlay.nix`](overlay.nix) file write a line inside the existing curly brackets following the following pattern:
        ```nix
        PACKAGE_NAME = (builtins.getFlake "github:nixos/nixpkgs/NIXPKGS_COMMIT_SHA1").legacyPackages.${system}.PACKAGE_NAME;
        ```
        Substitute `PACKAGE_NAME` and `NIXPKGS_COMMIT_SHA1` with affected package name and nixpkgs commit SHA1 (found at step 1), respectively.
    3. Commit the [`overlay.nix`](overlay.nix) changes. Configuration is ready to be built.
