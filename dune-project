(lang dune 3.15)

(name ddf)

(generate_opam_files true)

(source
 (github username/reponame))

(authors "Christian Todd")

(maintainers "Christian Todd")

(license LICENSE)

(documentation https://url/to/documentation)

(package
 (name ddf)
 (synopsis "discard directories quickly")
 (description "`mv`s directories and files to os tmpdir for quick cleanup")
 (depends ocaml dune)
 (tags
  (topics "to describe" your project)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
