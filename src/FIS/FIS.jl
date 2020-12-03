module FIS

#=
Device Interfacing
=#

# any device that interfaces with an FCS requires a bus.
mutable struct Bus
    data
    block::Bool

    Bus(type) = new(zeros(type, sizeof(type) * 8), false)
end

function write(bus::Bus, data)
    bus.data = data
    block = true
end

function read(bus::Bus)
    block = false
    data = bus.data
end

#=
FCS
=#
@enum Flag::UInt8 f_zero=0 f_carry=1 f_negative=2

struct FCS
    rom::Vector{UInt8}
    ram::Vector{UInt8}
    registers::Vector{UInt8} # $A $X $Y $Z flags pc stack_ptr
    out::Bus

    supp_math::Vector{Int}
end

function FCS()
    registers = zeros(UInt8, 0x7)
    registers[7] = 0x7F

    FCS(zeros(UInt8, 0x100), zeros(UInt8, 0x80), registers, Bus(UInt8), [1])
end

function prettyprint(fcs::FCS)
    println("FCS: A  X  Y  Z  FL PC SP")
    print("    ")

    for r in fcs.registers
        print(" ", lpad(uppercase(string(r, base = 16)), 2, "0"))
    end

    println()
end

function set_reg!(fcs::FCS, r::UInt8, value::UInt8)
    fcs.registers[r + 1] = value
end

function get_reg(fcs::FCS, r::UInt8)::UInt8
    fcs.registers[r + 1]
end

function set_pc!(fcs::FCS, addr::Integer)
    fcs.registers[6] = UInt8(addr)
end

function get_pc(fcs::FCS)::UInt8
    fcs.registers[6]
end

function pop_stack!(fcs::FCS)
    val = fcs.ram[fcs.registers[7]]
    fcs.registers[7] += 1
    val
end

function push_stack!(fcs::FCS, value::UInt8)
    fcs.ram[fcs.registers[7]] = value
    fcs.registers[7] -= 1
end

function set_flags!(fcs::FCS, r::UInt8, carry::Bool = false)
    flags::UInt8 = 0x00
    val = get_reg(fcs, r) # r should be where result of operation was put

    if val == 0 # zero
        flags += 0b1
    end
    if carry
        flags += 0b10
    end
    if Bool(val >> 7) # negative
        flags += 0b100
    end

    fcs.registers[5] = flags
end

function get_flag(fcs::FCS, flag::Flag)::Bool
    Bool((fcs.registers[5] >> UInt8(flag)) & 1)
end

function next_byte!(fcs::FCS)
    val = fcs.rom[fcs.registers[6] + 1]
    set_pc!(fcs, get_pc(fcs) + 1)
    val
end

# runs one clock cycle of the program
function tick!(fcs::FCS, debug::Bool = false)::Bool
    val = next_byte!(fcs)

    hi, lo = val >> 4, val & 0xF

    if debug
        println("Ticking $(string(val, base=16))...")
    end

    if hi == 0
        if lo == 1
            BRB()
        elseif lo == 2
            PPC()
        elseif lo >= 4
            x, r::UInt8 = lo >> 2, lo & 0x3
            if x == 1
                INC(fcs, r)
            elseif x == 2
                DEC(fcs, r)
            else # x == 3
                NOT(fcs, r)
            end
        end
    elseif hi <= 0xD
        iset1[hi](fcs, lo >> 2, lo & 0x3)
    else
        BCN(fcs, lo)
    end

    # returns whether program done
    get_pc(fcs) != 0xFF
end

function run!(fcs::FCS)
    while tick!(fcs) end
end

function load_program!(fcs::FCS, bytes::Vector{UInt8})
    length(bytes) > length(fcs.rom) && error("program too large to fit in rom")

    for i = 1:length(bytes)
        fcs.rom[i] = bytes[i]
    end
end

#=
Instruction Set
=#
function check_math_supp(fcs::FCS, r::UInt8)
    if !((r + 1) in fcs.supp_math)
        error("you can't do math with that register asshole")
    end
end

# all math ops do the same shit, no need to repeat
function do_math(fcs::FCS, op::Function, a::UInt8, b::UInt8) # a, b are registers
    check_math_supp(fcs, a)

    aval, bval = get_reg(fcs, a), get_reg(fcs, b)

    carry = Bool((op(UInt(aval), UInt(bval)) >> 8) & 1)

    set_reg!(fcs, a, UInt8(op(aval, bval)))
    set_flags!(fcs, a, carry)
end

function do_unary_math(fcs::FCS, op::Function, r::UInt8)
    check_math_supp(fcs, r)

    val = get_reg(fcs, r)

    carry = Bool((op(UInt(val)) >> 8) & 1)

    set_reg!(fcs, r, UInt8(op(val)))
    set_flags!(fcs, r, carry)
end

function BRB(fcs::FCS)
    set_pc!(fcs, pop_stack!(fcs))
end

function PPC(fcs::FCS)
    push_stack!(fcs, get_pc(fcs))
end

function INC(fcs::FCS, r::UInt8)
    do_unary_math(fcs, x->x + 1, r)
end

function DEC(fcs::FCS, r::UInt8)
    do_unary_math(fcs, x->x - 1, r)
end

function NOT(fcs::FCS, r::UInt8)
    do_unary_math(fcs, ~, r)
end

function MOV(fcs::FCS, r::UInt8, x::UInt8)
    set_reg!(r, get_reg(x))
end

function ADD(fcs::FCS, a::UInt8, b::UInt8)
    do_math(fcs, +, a, b)
end

function SUB(fcs::FCS, a::UInt8, b::UInt8)
    do_math(fcs, -, a, b)
end

function IOR(fcs::FCS, a::UInt8, b::UInt8)
    do_math(fcs, |, a, b)
end

function XOR(fcs::FCS, a::UInt8, b::UInt8)
    do_math(fcs, xor, a, b)
end

function AND(fcs::FCS, a::UInt8, b::UInt8)
    do_math(fcs, &, a, b)
end

function SHR(fcs::FCS, a::UInt8, b::UInt8)
    do_math(fcs, >>, a, get_reg(b))
end

function SHL(fcs::FCS, a::UInt8, b::UInt8)
    do_math(fcs::FCS, <<, a, get_reg(b))
end

function LDD(fcs::FCS, a::UInt8, b::UInt8)
    set_reg!(fcs, a, fcs.ram[get_reg(fcs, b) + 1])
end

function LDR(fcs::FCS, a::UInt8, b::UInt8)
    set_reg!(fcs, a, fcs.rom[get_reg(fcs, b) + 1])
end

function STR(fcs::FCS, a::UInt8, b::UInt8)
    fcs.ram[get_reg(fcs, b) + 1] = get_reg(fcs, a)
end

function BRC(fcs::FCS, b2::UInt8)
    set_pc!(fcs, b2)
end

function PSH(fcs::FCS, b2::UInt8)
    push_stack!(fcs, b2)
end

function MVI(fcs::FCS, r::UInt8, b2::UInt8)
    set_reg!(fcs, r, b2)
end

function LLD(fcs::FCS, r::UInt8, b2::UInt8)
    set_reg!(fcs, r, fcs.ram[b2])
end

function LLR(fcs::FCS, r::UInt8, b2::UInt8)
    set_reg!(fcs, r, fcs.rom[b2])
end

function RDR(fcs::FCS, r::UInt8)
    error() # TODO
end

function WRR(fcs::FCS, r::UInt8)
    error() # TODO
end

function WRI(fcs::FCS)
    b2 = next_byte!()

    error() # TODO
end

function BCN(fcs::FCS, lo::UInt8)
    b2 = next_byte!(fcs)
    zero, carry, negative, invert = [Bool((lo >> i) & 1) for i=0:3]

    print("branching conditional: ")

    invert && print("not ")
    zero && print("zero")
    carry && print("carry")
    negative && print("negative")

    println()

    cond = (zero && get_flag(fcs, f_zero)) || (carry && get_flag(fcs, f_negative)) || (negative && get_flag(fcs, f_negative))

    if invert ? !cond : cond
        println("conditions met.")
        set_pc!(fcs, b2)
    else
        println("conditions not met.")
    end
end

function C_OPS(fcs::FCS, x::UInt8, r::UInt8)
    b2 = next_byte!(fcs)

    if x == 0
        if r == 0
            BRC(fcs, b2)
        else # r == 1
            PSH(fcs, b2)
        end
    else
        if x == 1
            MVI(fcs, r, b2)
        elseif x == 2
            LLD(fcs, r, b2)
        else # x == 3
            LLR(fcs, r, b2)
        end
    end
end

function D_OPS(fcs::FCS, x::UInt8, r::UInt8)
    if x == 0
        RDR(fcs, r)
    elseif x == 1
        WRR(fcs, r)
    else # x == 2
        WRI(fcs)
    end
end

# instruction set from 0x1X - 0xCX
const iset1 = Dict(
    0x1 => MOV,
    0x2 => ADD,
    0x3 => SUB,
    0x4 => IOR,
    0x5 => XOR,
    0x6 => AND,
    0x7 => SHR,
    0x8 => SHL,
    0x9 => LDD,
    0xA => LDR,
    0xB => STR,
    0xC => C_OPS,
    0xD => D_OPS
)

#=
Assembler
=#
const asm_ops0 = Dict{String, UInt8}( # 0 operands
    "NOP" => 0x00,
    "BRB" => 0x01,
    "PPC" => 0x02,
    "RDN" => 0x03
)

const asm_ops1 = Dict{String, UInt8}( # 1 operand; a register
    "INC" => 0x04,
    "DEC" => 0x08,
    "NOT" => 0x0C,
    "RDR" => 0xD0,
    "WRR" => 0xD4
)

const asm_ops2 = Dict{String, UInt8}(
    "MOV" => 0x10,
    "ADD" => 0x20,
    "SUB" => 0x30,
    "IOR" => 0x40,
    "XOR" => 0x50,
    "AND" => 0x60,
    "SHR" => 0x70,
    "SHL" => 0x80,
    "LDD" => 0x90,
    "LDR" => 0xA0,
    "STR" => 0xB0
)

const asm_iops0 = Dict{String, UInt8}(
    "BRC" => 0xC0,
    "PSH" => 0xC1,
    "WRI" => 0xDC
)

const asm_iops1 = Dict{String, UInt8}(
    "MVI" => 0xC4,
    "LLD" => 0xC8,
    "LLR" => 0xCC
)

# BCN and BFN explicitly checked

const register_nums = Dict{Char, UInt8}(
    'A' => 0,
    'X' => 1,
    'Y' => 2,
    'Z' => 3
)

const setup = Vector{UInt8}([0xc4, 0x00, 0xc6, 0x12, 0x32, 0x08, 0x22, 0xa4, 0x32, 0xb4, 0xe9, 0x05, 0xc5, 0x00, 0xc6, 0x00, 0xc0, 0x00])

# TODO setup

function assemble(program::String)::Vector{UInt8}
    # sanitize
    lines = split(program, "\n")
    for i = 1:length(lines)
        j = findfirst(';', lines[i])

        if j != nothing
            lines[i] = lines[i][1:j - 1]
        end

        lines[i] = strip(lines[i])
    end

    filter!(x -> length(x) > 0, lines)

    # separate into sections
    sections = Dict(
        ".rodata" => Vector{String}(),
        ".data" => Vector{String}(),
        ".text" => Vector{String}()
    )
    curr = nothing

    for line in lines
        if startswith(line, ".")
            if !(line in keys(sections))
                error("Invalid section identifier $line")
            end
            curr = line
        elseif curr != nothing
            push!(sections[curr], line)
        end
    end

    # compile
    labels = Dict{String,UInt8}()
    program = [n for n in setup]
    addr::UInt8 = length(setup)

    char_to_uint8(c) = begin
        try
            convert(UInt8, codepoint(c))
        catch
            error("Invalid ASCII char \"$c\"")
        end
    end

    process_labels(line) = begin
        if contains(line, ':')
            i = findfirst(':', line)
            lbl = line[1:i - 1]

            if match(r"\W", lbl) != nothing
                error("Invalid label \"$lbl\"")
            end

            labels[lbl] = addr
            line = line[i + 1:length(line)]
        end
        line
    end

    get_literal(operand) = begin
        if startswith(operand, '\$')
            if length(operand) > 2 || !(operand[2] in keys(register_nums))
                 error("Invalid register $operand")
            end
            return register_nums[operand[2]]
        elseif startswith(operand, '#')
            return parse(UInt8, operand[2:length(operand)], base = 16)
        elseif startswith(operand, '\'') && endswith(operand, '\'') && length(operand) == 3
            return char_to_uint8(operand[2])
        elseif operand in keys(labels)
            return labels[operand]
        else
            error("Invalid operand \"$operand\"")
        end
    end

    for section in (".data", ".rodata")
        for line in sections[section]
            line = process_labels(line)

            if length(line) == 0
                continue
            end

            if startswith(line, "\"") && endswith(line, "\"")
                for c in line[2:length(line) - 1]
                    push!(program, char_to_uint8(c))
                    addr += 1
                end
                push!(program, UInt8(0x00))
                addr += 1
            else
                push!(program, get_literal(line))
                addr += 1
            end
        end

        if section == ".data"
            program[2] = addr
        end
    end

    program[length(setup)] = addr

    for line in sections[".text"]
        line = split(process_labels(line))

        if length(line) != 0
            op = line[1]
            params = []

            if op != "BCN" && length(line) > 1
                params = [get_literal(line[i]) for i = 2:length(line)]
            end

            if op in keys(asm_ops0)
                push!(program, asm_ops0[op])
            elseif op in keys(asm_ops1)
                push!(program, asm_ops1[op] | params[1])
            elseif op in keys(asm_ops2)
                push!(program, asm_ops2[op] | ((params[1] << 2) | params[2]))
            elseif op in keys(asm_iops0)
                push!(program, asm_iops0[op])
                push!(program, params[1])
                addr += 1
            elseif op in keys(asm_iops1)
                push!(program, asm_iops1[op] | params[1])
                push!(program, params[2])
                addr += 1
            else
                if op == "BCN"
                    cond::UInt8 = 0x00
                    cid, a = line[2:3]
                    a = get_literal(a)

                    if startswith(cid, 'N')
                        cond |= 0x8
                    end

                    #if endswith(cid, "LZ") # TODO

                    #elseif endswith(cid, "GZ") # TODO


                    if endswith(cid, 'C')
                        cond |= 0x2
                    elseif endswith(cid, 'Z')
                        cond |= 0x1
                    end

                    push!(program, UInt8(0xE0 | cond))
                    push!(program, a)

                    addr += 1
                else
                    error("Invalid instruction $op")
                end
                # TODO BFN
            end

            addr += 1
        end
    end

    program # fuck yeah :)
end

end # module
