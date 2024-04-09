# mv_rmrf

> A CLI utility similar to `rm -rf` that runs faster by moving files to the OS's tmp directory.

## Setup

1. [Install `opam`](https://opam.ocaml.org/doc/Install.html)
2. Install dependencies from the lockfile
   ```sh
   opam install ./lib.opam.locked ./bin.opam.locked ./mv_rmrf.opam --deps-only --locked
   ```
3. Build with `dune`
   ```sh
   dune build bin
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
