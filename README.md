# elm-small-spa
`elm-small-spa` is an single-file SPA example written in Elm, implements

* routing
* port (both JS -> Elm and Elm -> JS),

can be used for educational purpose, or can be used as the first template of your project.

## Usage
Please install Docker Host in the first.

### Build development environment container image

```
$ make build
```

### Enter the container's shell

```
$ make shell
```

### Compile Elm program

```
$ make elm
```

### Start elm-live

```
$ make serve
```

Ctrl+C to stop elm-live.
