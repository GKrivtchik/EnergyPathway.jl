"""
Behavior: fixed deployment.
"""

struct FixedDeployment{M<:Function} <: AbstractDeploymentData
    pname::String
    modifier::M
    val::Float64
end

"""
    FixedDeployment(pname::String; lb::Number=0., ub::Number=Inf)
Return a FixedDeployment behavior data, associated with port name `pname` and modifier `modifier`.
Optional parameters:
* lb: lower bound
* ub: upper bound
"""
function FixedDeployment(pname::String, modifier::Function, val::Number)
    @argcheck val >= 0. "Deployment cannot be negative"
    FixedDeployment(pname, modifier, Float64(val))
end

struct FixedDeploymentBehavior{T<:VAL,M<:Function} <: AbstractDeploymentBehavior{T}
    data::FixedDeployment{M}
    val::T
end

# return a FixedDeploymentBehavior
function buildbehavior(c::Component, b::FixedDeployment)    
    @argcheck hasport(c, b.pname) "Component does not have port named $(b.pname)"
    @argcheck hasmodifier(getport(c, b.pname), b.modifier) "Target port does not have the required modifier"

    return FixedDeploymentBehavior(b, _to_affexpr(b.val, sim(c).model))
end

# deployment constraint is handled at Path level

_apply_constraints!(::Component, ::FixedDeploymentBehavior) = nothing

behaviorname(::FixedDeploymentBehavior) = "fixed deployment"

# return the GenericAffExpr
_deployment(c::FixedDeploymentBehavior) = c.val

_portname(c::FixedDeploymentBehavior) = c.data.pname
_modifier(c::FixedDeploymentBehavior) = c.data.modifier