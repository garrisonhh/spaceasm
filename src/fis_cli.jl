include("./FIS/FIS.jl")
const fis = FIS

function prettyprint(v::Vector{UInt8})
    for i = 1:length(v)
        print("$(lpad(uppercase(string(v[i], base=16)), 2, '0')) ")
        i % 16 == 0 && println()
    end
    length(v) % 16 != 0 && println()
end

function main()
    length(ARGS) != 1 && error("Wrong number of args, please submit a relative file path")

    text = ""
    open(joinpath(@__DIR__, ARGS[1]), "r") do file
        text = read(file, String)
    end

    sys = fis.FCS()
    in_b = fis.InputBus()
    out_b = fis.OutputBus()
    fis.connect_in!(sys, in_b)
    fis.connect_out!(sys, out_b)

    program = fis.assemble(text)

    println("Program:")
    prettyprint(program)
    println()

    fis.load_program!(sys, program)
    fis.run!(sys)

    println("> $(fis.get_output(out_b))")
    println()
    println("Program completed successfully.")
end

main()
