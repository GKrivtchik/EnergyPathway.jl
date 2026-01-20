"""
Pathway extraction.
"""

import Nosy: extract, _extract
using JuMP: GenericAffExpr

function extract(p::Path{<:GenericAffExpr})
    m = p.sim.model
    if is_solved_and_feasible(m)
        return _extract(p)
    elseif termination_status(m) == OPTIMIZE_NOT_CALLED
        throw(AssertionError("Optimizer was not called"))
    else
        @warn "System is not optimized. Termination status: $(termination_status(m)). Returning the problem instead of the result."
        return p
    end
end
extract(::Path{Float64}) = throw(ArgumentError("Path is already extracted"))