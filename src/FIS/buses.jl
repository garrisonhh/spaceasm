#=
Device Interfacing
=#
# any device that can be read from by an FCS requires a bus.
abstract type Bus end

set_data!(bus::Bus, data::UInt8) = bus.value = data
get_data(bus::Bus)::UInt8 = bus.value

# redefine write_data and read_data for a bus type to change transfer_data behavior
write_data!(bus::Bus, data::UInt8) = set_data(bus::Bus, data::UInt8)
read_data!(bus::Bus) = get_data(bus::Bus)
transfer_data!(a::Bus, b::Bus) = write_data!(b, read_data!(a))

#=
Devices
=#
mutable struct FCSBus <: Bus
    value::UInt8

    # set to block while waiting for sync
    reading::Bool
    writing::Bool

    FCSBus() = new(UInt8(0), false, false)
end

function write_data!(bus::FCSBus, data::UInt8)
    bus.reading = false
    set_data(bus::Bus, data::UInt8)
end

function read_data!(bus::FCSBus)
    bus.writing = false
    get_data(bus::Bus)
end

# standard input
mutable struct InputBus <: Bus
    values::Vector{UInt8}

    writing::Bool # always true

    InputBus() = new([], true)
end

add_input!(bus::InputBus, str::String) = values = vcat(values, collect(codeunits(str)))

write_data!(bus::InputBus, data::UInt8) = error("Cannot write to an InputBus")

function read_data!(bus::InputBus)
    length(values) == 0 && error("Attempting to read from empty InputBus")
    pop!(values)
end

# standard output
mutable struct OutputBus <: Bus
    str::String

    reading::Bool

    OutputBus() = new("", true)
end

get_output(bus::OutputBus) = bus.str

function write_data!(bus::OutputBus, data::UInt8)
    ch = Char(data)
    if isprint(ch)
        bus.str *= ch
    end
end
read_data!(bus::OutputBus) = error("Cannot read from an OutputBus")
