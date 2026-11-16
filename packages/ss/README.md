# ss

OCaml dotfiles helper built on `Bos`, invoked via the thin Fish wrapper in `config/fish/functions/ss.fish` (with Nix metadata `SS_BIN`, `SS_HOST`, `SS_HOSTS`, `SS_INPUTS` exported by `modules/shell/fish.nix`).

```sh
nix run path:.#ss -- help  # standalone from the dotfiles root
```

Development with `direnv`:

```sh
cd packages/ss
direnv allow
dune build
dune runtest
dune exec ss -- help
```
