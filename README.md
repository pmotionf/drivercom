# drivercom

> PMF Smart Driver Communications Library.

## Building

### Library

To build `drivercom` as a static or dynamic C library, the `library` option
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

## Usage

### CLI

#### Linux

Ensure that the user is part of the `dialout` group for serial connections.
