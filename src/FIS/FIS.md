## **F**antasy **I**nstruction **S**et Reference
Loosely based around RISC architectures and my super limited experience with 4004 and 6502 assembly. Names for chips and the language are WIP and I'm sure I'll rename them like 15 times.

The goal for this instruction set and these "hardware" specifications is to provide a fun and interesting challenge without breaking immersion, not pure realism. If you read this and you're an assembly expert I'd still appreciate critique, though!

### The FIS
#### Syntax
- Execution
    - All operations are performed beginning with the `.text`
    - A valid line of FIS Assembly consists of one of three things:
        - A label or section identifier.
        - An instruction expression.
        - Neither.
    - At the end of any valid line, a `;` marks the beginning of a comment: `; this is a comment`
- Operands
    - Registers are written with a prefixed `$`: `$A $0 $1`
    - Immediate values are written with a prefixed `#`: `#0 #B #7`
        - Immediate values are written in hexadecimal by default. Binary is also supported with an infixed `b`: #b00100010
        - Immediate values are unsigned by default. Signed values use an infixed `+` or `-`: `#-10 #+2A`
    - Character and String support
        - Use the equivalent C syntax of `'c'` and `"str"` respectively
        - Characters are simply ASCII encoded values, directly translatable to unsigned immediate values.
            - Strings are zero-terminated strings of characters. The only way to use a string is by writing it in the `.data` section and using a label.
            - There is only one true type, the integer. To the assembler, `#41` is equivalent to `'A'`
- Sections, Labels, and Procedures
    - Sections are marked with a prefixed `.`.
        - There are 3 sections:
            - `.text` which contains the program to execute.
            - `.data` which contains readable and writeable labels and literals
            - `.rodata` which contains read-only labels and literals
    - Labels are marked with a suffix `:`.
        - Labels are an easy way to represent addresses in memory in your code without having to change them every time you change your code. The assembler replaces all label references with the memory address where they reference.
        - In the `.data` section, labels allow you to access stored constants easily.
        - In the `.text` section, labels allow you to control the flow of the program.
    - Procedures are like functions, use BFN or B
- Conditions
    - The special flags register contains bits that are triggered by certain conditions that the last math operation performed met. These are used in some conditional operations.
        - `Z` zero flag: last operation resulted in a zero
        - `C` carry flag: last operation resulted in a carry value
        - negative flag: last operation resulted in a number where signed bit is 1. This allows for `LZ` (less than zero) and `GZ` (greater than zero) conditions. For unsigned numbers this isn't going to be accurate all the time of course
        - `N` invert: condition prefix denoting inversion; `NZ` = not zero

#### Instructions
| Expression | Opcode | Pseudocode Equivalent | Notes
| :------ | :-- | :-- | :--
NOP       | 0000 0000
BRB       | 0000 0001 | set PC to popped stack address. | Used to return from functions.
PPC       | 0000 0010 | push PC onto stack
RDN       | 0000 0011 | read nowhere; sync signals | TODO
INC $R    | 0000 01RR | $R ++ | Triggers flags.
DEC $R    | 0000 10RR | $R -- | Triggers flags.
NOT $R    | 0000 11RR | $R = ~$R | Triggers flags.
MOV $R $X | 0001 RRXX | $R = $X
ADD $R $X | 0010 RRXX | $R += $X | Triggers flags.
SUB $R $X | 0011 RRXX | $R -= $X | Triggers flags.
IOR $R $X | 0100 RRXX | $R \|= $X | Triggers flags.
XOR $R $X | 0101 RRXX | $R ^= $X | Triggers flags.
AND $R $X | 0110 RRXX | $R &= $X | Triggers flags.
SHR $R $X | 0111 RRXX | $R >>= $X | Triggers flags.
SHL $R $X | 1000 RRXX | $R <<= $X | Triggers flags.
LDD $R $X | 1001 RRXX | load value at address $X into $R | RAM (.data) address.
LDR $R $X | 1010 RRXX | load value at address $X into $R | ROM (.rodata) address.
STR $R $X | 1011 RRXX | store value of $R at address $X | RAM address.
BRC #I/lbl| 1100 0000 LLLL LLLL | set PC to ROM address.
PSH lbl   | 1100 0001 IIII IIII | push address onto stack | ROM address.
MVI $R #I | 1100 01RR IIII IIII | $R = #I
LLD $R lbl| 1100 10RR LLLL LLLL | load value at address lbl into $R | RAM (.data) address.
LLR $R lbl| 1100 11RR LLLL LLLL | load value at address lbl into $R | ROM (.rodata) address.
RDR $R    | 1101 00RR | Read input bus to register.
WRR $R    | 1101 01RR | Write register to bus.
BCN cond lbl | 1110 CCCC LLLL LLLL | set PC to label if cond | See conditions.
BFN lbl   | n/a | push current PC and then set PC to label | See procedures. (compiles to PPC BRC)

\* signed ops not functional  
\*\* labels and immediate values are interchangeable  
\*\*\* RDR and WRR are blocking. Nothing will be executed until a value is read or written.

#### File Binary Format
- the first bytes are reserved for the setup sequence, which is just a small FIS program itself.
    - this program moves anything declared in `.data` to RAM on initialization.
```
MVI \$A #00 ; set addr #01 to end of .data
MVI \$Y #12
SUB \$A \$Y
loop:
DEC \$A

ADD \$A \$Y
LDR \$X \$A

SUB \$A \$Y
STR \$X \$A

BCN NZ loop

MVI \$X #00
MVI \$Y #00

BRC #00     ; set addr #12 to beginning of .text
```
        - the addresses for the first `MVI` and last `BRC` ops are dependent on the rest of the program, and are determined at compile-time
        - if the `.data` section is unused, the setup sequence is simply:
```
BRC #00     ; set addr #01 to beginning of .text
```
- sections are then loaded in order:
    1. `.data`
    2. `.rodata`
    3. `.text`

### "System" Specs
- exclusively 8 bit system
    - memory addressing and integers limited to 8 bit width
    - index registers
        - $A (accumulator), which supports math
        - $X, $Y, and $Z, which do not support math but can be written to and from
    - special registers
        - flags register
        - program counter
        - stack pointer
