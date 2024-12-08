# BF

**WARNING:** This project is in early development and may contain bugs.

BF is based on a [similar named language](https://en.wikipedia.org/wiki/Brainfuck) written for the Agon Light 2 computer

BF is written in ez80 assembly using the [ez80asm](https://github.com/envenomator/agon-ez80asm) assembler.

It consists of only 8 commands

| Character | Instruction Performed |
| --------- | --------------------- |
| `>` | Increment the data pointer by one (to point to the next cell to the right). |
| `<` | Decrement the data pointer by one (to point to the next cell to the left). |
| `+` | Increment the byte at the data pointer by one. |
| `-` | Decrement the byte at the data pointer by one. |
| `.` | Output the byte at the data pointer. |
| `,` | Accept one byte of input, storing its value in the byte at the data pointer. |
| `[` | If the byte at the data pointer is zero, then instead of moving the instruction pointer forward to the next command, jump it forward to the command after the matching ] command. |
| `]` | If the byte at the data pointer is nonzero, then instead of moving the instruction pointer forward to the next command, jump it back to the command after the matching [ command. |

Any other character is ignored with the exception of $FF which will terminate the program.

## Memory Map

| Memory | Description |
| ------ | ----------- |
| $50000-$57FFF | Virtual machine's tape memory |
| $60000 | Location of source file |

Note: There are no bounds checking, so if you go outside of this memory map then beware of gremlins.

## How to use

Create your bf code in a sourcefile. Then you can simply launch the interpreter with the following command

    BF <sourcefile>

This will load the sourcefile into memory at location $060000 and interpret the file using a 32k 'tape' $050000.

For usage information, just issue the command BF on its own (without parameters)

    BF

## TODO

The following thigs are on my todo list:

- [X] Command line parameters
  - [x] Load a file on the command line
  - [X] Display parameter help output
- [ ] Debug mode
  - [ ] Program stepper
