module FIS
include("./fcs.jl")
include("./assembler.jl")
include("./buses.jl")

#=
# asm
export assemble
# fcs
export FCS, connect_in!, connect_out!, tick!, run!, load_program!
# buses
=#

end # module
