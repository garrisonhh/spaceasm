#=
FIS Assembler
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

#= setup program:
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

    BRC #00     ; set addr #12 to start of .text
=#
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

                    if endswith(cid, "LZ") # negative
                        cond |= 0x4
                    elseif endswith(cid, "GZ") # not negative
                        cond |= 0x8
                        cond |= 0x4
                    else
                        if startswith(cid, 'N')
                            cond |= 0x8
                        end
                        if endswith(cid, 'C')
                            cond |= 0x2
                        elseif endswith(cid, 'Z')
                            cond |= 0x1
                        end
                    end

                    push!(program, UInt8(0xE0 | cond))
                    push!(program, a)

                    addr += 1
                elseif op == "BFN"
                    push!(program, asm_ops0["PPC"])
                    push!(program, asm_iops0["BRC"])
                    push!(program, params[1])
                    addr += 2
                else
                    error("Invalid instruction $op")
                end
            end

            addr += 1
        end
    end

    program # fuck yeah :)
end
