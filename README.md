# drivercon

> PMF Smart Driver RS232 Serial Connection Library.

## Building

### Library

To build `drivercon` as a static or dynamic C library, the `library` option
must be specified.

```console
zig build -Dlibrary=static
```

```console
zig build -Dlibrary=dynamic
```

### CLI

To build the accompanying CLI utility, the `cli` option must be specified.

```console
zig build -Dcli
```