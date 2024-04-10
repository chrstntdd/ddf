(lang dune 3.15)

(name ddf)

(generate_opam_files true)

(source
 (github chrstntdd/ddf))

(authors "Christian Todd")

(maintainers "Christian Todd")

(license MIT)

(documentation https://url/to/documentation)

(package
 (name lib)
 (synopsis "utils for `ddf` cli")
 (description "Library functions to support `ddf` cli")
 (depends eio_main))

(package
 (name ddf)
 (synopsis "discard directories fast")
 (description
  "cli to `mv` directories and files to os tmpdir for quick cleanup")
 (depends eio_main cmdliner lib))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
