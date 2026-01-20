using Nosy: AbstractElement, Snapshot

# snapshot with some metadata
struct MetaSnapshot{T} <: AbstractElement{T}
    year::Int64
    snap::Snapshot{T}
end