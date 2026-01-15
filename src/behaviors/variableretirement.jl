"""
Behavior: variable retirement.
"""

struct VariableRetirement{M<:Function} <: AbstractRetirementData
    pname::String
    modifier::M
    lb::Float64
    ub::Float64
end

"""
    VariableRetirement(pname::String; lb::Number=0., ub::Number=Inf)
Return a VariableRetirement behavior data, associated with port name `pname` and modifier `modifier`.
Optional parameters:
* lb: lower bound
* ub: upper bound
"""
function VariableRetirement(pname::String, modifier::Function; lb::Number=0., ub::Number=Inf)
    @argcheck lb >= 0. "Retirement cannot be negative"
    @argcheck lb <= ub "Lower bound is bigger than upper bound"
    VariableRetirement(pname, modifier, Float64(lb), Float64(ub))
end

struct VariableRetirementBehavior{T<:VAL,M<:Function} <: AbstractRetirementBehavior{T}
    data::VariableRetirement{M}
    val::T
end

# return a VariableRetirementBehavior
function buildbehavior(c::Component, b::VariableRetirement)    
    @argcheck hasport(c, b.pname) "Component does not have port named $(b.pname)"
    @argcheck hasmodifier(getport(c, b.pname), b.modifier) "Target port does not have the required modifier"
    cap = getcapacitybehavior(c, b.pname) # same port
    @argcheck cap.data.modifier == b.modifier "Retirement must have same modifier as capacity"

    v = @variable(lowermodel(sim(c)), base_name=name(c) * "_" * b.pname * "_" * modifiername(b.modifier) * "_" * "ret" * "_" * sim(c).suffix, lower_bound=b.lb, upper_bound=b.ub, integer=false, binary=false)
    e = _to_affexpr(v, sim(c).model)

    return VariableRetirementBehavior(b, e)
end

# retirement constraint is handled at Path level

_apply_constraints!(::Component, ::VariableRetirementBehavior) = nothing

behaviorname(::VariableRetirementBehavior) = "variable retirement"

# return the GenericAffExpr
_retirement(c::VariableRetirementBehavior) = c.val

_portname(c::VariableRetirementBehavior) = c.data.pname
_modifier(c::VariableRetirementBehavior) = c.data.modifier