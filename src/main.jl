include("FIS/FIS.jl")

# setup program:
#= """
.text
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
""" =#

test = """
.data
s:
    "Hello World!"
"""

function main()
    program = FIS.assemble(test)

    println("Program:")
    for i = 1:length(program)
        print("$(lpad(string(program[i], base=16), 2, '0')) ")
        i % 8 == 0 && println()
    end

    sys = FIS.FCS()

    FIS.load_program!(sys, program)

    while FIS.tick!(sys, true)
        #=
        FIS.prettyprint(sys)
        print("RAM: ")
        for i = 1:16
            print("$(lpad(string(sys.ram[i], base=16), 2, '0')) ")
        end
        println()
        sleep(0.1)
        =#
    end

    print("RAM: ")
    for i = 1:16
        print("$(lpad(string(sys.ram[i], base=16), 2, '0')) ")
    end
    println()
end

main()
