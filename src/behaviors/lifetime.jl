"""
Behavior: life time.
"""

struct Lifetime <: AbstractPathBehaviorData
    years::Int64

    @doc"""
        Lifetime(years::Int)
    Return a Lifetime behavior data.
    """
    function Lifetime(years::Int)
        @argcheck years > 0 "years must be a strictly positive integer"
        new(Int64(years))
    end
end

struct LifetimeBehavior{T<:VAL} <: AbstractPathBehavior{T}
    data::Lifetime
    _type::Type{T}
end

function buildbehavior(::Component{T}, b::Lifetime) where T
    return LifetimeBehavior(b,T)
end

_apply_constraints!(::Component, ::LifetimeBehavior) = nothing

behaviorname(::LifetimeBehavior) = "lifetime"

_lifetime(b::LifetimeBehavior) = b.data.years