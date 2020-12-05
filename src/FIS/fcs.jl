include("buses.jl")

#=
FCS
=#
@enum Flag::UInt8 f_zero=0 f_carry=1 f_negative=2

struct FCS
    rom::Vector{UInt8}
    ram::Vector{UInt8}
    registers::Vector{UInt8} # $A $X $Y $Z flags pc stack_ptr

    buses::Dict

    supp_math::Vector{Int}
end

function FCS()
    registers = zeros(UInt8, 0x7)
    registers[7] = 0x7F

    FCS(zeros(UInt8, 0x100), zeros(UInt8, 0x80), registers, Dict("out" => Bus(), "in" => nothing), [1])
end

#=
External (exported in FIS)
=#
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

function connect!(fcs::FCS, in_bus::Bus)
    fcs.buses["in"] = in_bus
end

#=
Internal
=#
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

    cond = (zero && get_flag(fcs, f_zero)) || (carry && get_flag(fcs, f_negative)) || (negative && get_flag(fcs, f_negative))

    if invert ? !cond : cond
        set_pc!(fcs, b2)
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
