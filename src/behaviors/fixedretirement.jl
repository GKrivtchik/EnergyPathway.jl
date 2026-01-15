"""
Behavior: fixed retirement.
"""

struct FixedRetirement{M<:Function} <: AbstractRetirementData
    pname::String
    modifier::M
    val::Float64
end

"""
    FixedRetirement(pname::String; lb::Number=0., ub::Number=Inf)
Return a FixedRetirement behavior data, associated with port name `pname` and modifier `modifier`.
Optional parameters:
* lb: lower bound
* ub: upper bound
"""
function FixedRetirement(pname::String, modifier::Function, val::Number)
    @argcheck val >= 0. "Retirement cannot be negative"
    FixedRetirement(pname, modifier, Float64(val))
end

struct FixedRetirementBehavior{T<:VAL,M<:Function} <: AbstractRetirementBehavior{T}
    data::FixedRetirement{M}
    val::T
end

# return a FixedRetirementBehavior
function buildbehavior(c::Component, b::FixedRetirement)    
    @argcheck hasport(c, b.pname) "Component does not have port named $(b.pname)"
    @argcheck hasmodifier(getport(c, b.pname), b.modifier) "Target port does not have the required modifier"

    return FixedRetirementBehavior(b, _to_affexpr(b.val, sim(c).model))
end

# retirement constraint is handled at Path level

_apply_constraints!(::Component, ::FixedRetirementBehavior) = nothing

behaviorname(::FixedRetirementBehavior) = "fixed retirement"

# return the GenericAffExpr
_retirement(c::FixedRetirementBehavior) = c.val

_portname(c::FixedRetirementBehavior) = c.data.pname
_modifier(c::FixedRetirementBehavior) = c.data.modifier