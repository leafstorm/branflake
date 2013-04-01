# Branflake

Branflake is a compiler for the Brainf--- language. Its target platform
is 16-bit DOS. I made it using the techniques in NC State University's
[CSC 236][] class.

[CSC 236]: http://courses.ncsu.edu/csc236/lec/001/


## 16-bit DOS? How the flake am I supposed to use it?

Most people don't have 16-bit DOS lying around on an actual machine, so
the best approach (and the one that I used when developing it) is to
install [DOSBox][].

Branflake, and the assembler it generates, is written for the Microsoft Macro
Assembler (MASM), since that is what CSC 236 uses. I plan to support
[JWASM][] as well since it is free, open-source, and MASM-compatible,
and if compatibility with other assemblers can be provided without adding
complexity to `bftrans`, that's great. Pull requests are welcome.

[DOSBox]: http://www.dosbox.com/
[JWASM]: http://www.japheth.de/JWasm.html


## Language Reference

Branflake, as a dialect of Brainf---, is an esoteric and rather difficult
language to write in. However, it's very easy to compile, and Branflake even
performs some optimizations on the generated assembly.

A Branflake program has access to the entire 64K data segment, which it can
access one byte at a time, like the mathematical ideal of a Turing machine.
It has one register (the "data pointer"), which indicates the byte in memory
it is currently manipulating (the "current byte").

There are eight instructions in Branflake (names given only to explain the
source code):

* `>` (`next`) increments the data pointer by one.
* `<` (`prev`) decrements the data pointer by one.
* `+` (`inc`) increments the current byte by one.
* `-` (`dec`) decrements the current byte by one.
* `[` (`skip`) skips the bracketed section if the current byte is zero.
* `]` (`loop`) repeats the bracketed section if the current byte is nonzero.
* `.` (`write`) writes the current byte to standard output.
* `,` (`read`) reads a byte from standard input and stores it in the current byte.

All other characters are comments. The only syntax errors are mismatched
brackets -- either having a `]` when all previous `[` have been closed, or
having a `[` that is not closed by a `]`. These are reported by dropping a
`.ERR` directive in the generated source so that assembly fails.

Each instruction is executed sequentially (taking the effects of `[` and `]`
into account), until the last instruction completes, at which point the
program will exit.

Branflake offers no mechanisms for handling overflows, underflows, or other
mathematical imprecisions. As a consequence, the data pointer will "wrap
around" if increased above 65535 or decreased below 0, and individual bytes
in memory will wrap around if increased above 255 or decreased below 0.


## Invocation

The core of Branflake is `bftrans.asm`, which is a very simple translator.
It accepts Branflake instructions on standard input, and writes assembler
code on standard output. You can assemble and link `bftrans` using MASM
by running the included `make.bat` file.

`bftrans` is supported by `bfio.asm`, which contains some I/O abstraction
subroutines (which are prototyped in `bfio.inc`). These provide character
and line counting, and some functions for formatting output.

Once `bftrans` has been linked, you can invoke it directly, or use `bfml.bat`
to translate, assemble, and link your Branflake source in a single step.
Its usage is:

    bfml hello

Which will assemble a file named `hello.bf` into `hello.exe`, generating
`hello.asm` and `hello.obj` along the way.


## Implementation Details

In the generated assembly, the data pointer is represented by `bx`, and the
current byte by `[bx]`. The `ax` and `dx` registers are used temporarily
for I/O purposes, but in general, all operations are done in memory.


## Current Limitations

* Currently, there are no optimizations.
* All assembler files must be terminated by a DOS EOF character (1Ah).
* Most Brainf--- code on the Internet isn't used to having to check for a
DOS EOF to end input.
