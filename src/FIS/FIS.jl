module FIS
include("fcs.jl")
include("assembler.jl")
include("buses.jl")

# asm
export assemble
# fcs
export FCS, connect!, tick!, run!, load_program!
# buses
# export Bus

end # module
