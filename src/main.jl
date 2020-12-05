include("FIS/FIS.jl")
const fis = FIS

test = """
.rodata
msg:
    "Hello World!"
.text

"""

function main()
    program = fis.assemble(test)

    println("Program:")
    for i = 1:length(program)
        print("$(lpad(uppercase(string(program[i], base=16)), 2, '0')) ")
        i % 8 == 0 && println()
    end

    sys = fis.FCS()
    fis.load_program!(sys, program)
    fis.run!(sys)
end

main()
