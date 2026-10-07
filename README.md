# gitz

Git with zero system dependencies. Configure your own FS, HTTP, and random at
build and run time.

## Why?

Portability, especially for browser WASM. [WIT](1) is supposed to provide a
cross-language ABI, but the reality is that:

1. the [binding generation](2) can only target a few languages that aren't Zig
2. the standard component models for FS and HTTP [are brand new](3) and [crypto
   has not yet been released](4)
  - surface is much larger than what Git needs! currently no solution to only
    use what's needed to reduce hosts binary bloat
3. host language support only exists for a handful of languages
  - browser shims are huge, partial, ugly, and not tree-shakeable

Once these issues are solved, WIT is worth considering if runtime performance
is competitive. The biggest issue is that functions that return non-scalar
values must allocate and return a pointer.

[1]: https://component-model.bytecodealliance.org/design/why-component-model.html
[2]: https://github.com/bytecodealliance/wit-bindgen
[3]: https://wasi.dev/releases/wasi-p3#wasifilesystem
[4]: https://github.com/WebAssembly/wasi-crypto
