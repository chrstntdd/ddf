# `ddf`

> `d`iscard `d`irectories `f`ast

> [!IMPORTANT]
> `mv`s directories and files to os tmpdir for quick cleanup

## Why

I wanted to try out Ocaml 5 and with the new stable `eio` library. Also, clearing out `node_modules` and other build artifacts with `rm -rf` takes too long for me.

## Setup

1. [Install `opam`](https://opam.ocaml.org/doc/Install.html)
2. Create a local switch with `opam`

   ```sh
   opam switch create . --deps-only
   ```

   This command will read all the `*.opam` files and download all dependencies

3. Build CLI with `dune` from the local switch
   ```sh
   opam exec -- dune build bin
   ```
4. Verify `ddf.exe`
   ```sh
   eza --tree ./_build/default
   ```

    ```sh
    ./_build/default
    ├── bin
    │  ├── ddf.exe # 👈
    │  ├── ddf.ml
    │  └── ddf.mli
    ├── ddf.dune-package
    ├── ddf.install
    ├── ddf.opam
    ├── lib
    │  ├── fs.ml
    │  ├── lib.a
    │  ├── lib.cma
    │  ├── lib.cmxa
    │  ├── lib.cmxs
    │  └── lib.ml-gen
    ├── lib.dune-package
    ├── lib.install
    ├── lib.opam
    ├── META.ddf
    ├── META.lib
    └── README.md
    ```

For production, be sure to include the release flag:

```sh
dune build --profile release bin
```

## Development

Run `dune` in watch mode to get a fast development feedback loop.

```sh
dune exec bin/main.exe --watch -- --help
```

## Execution

Once the built with `dune`, you can invoke the executable directly:

```sh
./_build/default/bin/main.exe --help
```

or with `dune`

```sh
dune exec/bin/main.exe -- --help
```

If you are consuming the binary from the build artifacts, ensure you allow the `main.exe` to be executable:

```sh
chmod +x main.exe
```

## Prior art

- [`rip`](https://github.com/nivekuil/rip)
- [`mvf`](https://github.com/chrstntdd/mvf)
  The first prototype of this same functionality in ReasonML without the nice CLI. If I can ever get the build tooling right, it would be nice to have Pastel back in the mix somehow. Maybe a single module for rendering CLI output prompts in ReasonML with native jsx? 🤔
