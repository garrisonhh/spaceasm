#=
Device Interfacing
=#

# any device that can be read from by an FCS requires a bus.
mutable struct Bus
    data::UInt8
    block::Bool

    Bus() = new(UInt8(0), false)
end

function read(bus::Bus)::UInt8
    bus.block = false
    bus.data
end
