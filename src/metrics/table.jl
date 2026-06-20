"""
Path table metrics.
"""

using DataFrames: DataFrame

import Nosy: table

"""
    table(path, metric; removenothing=true)

Return a DataFrame containing `metric(path, component_name, year)` for every
year in `allyears(path)` and every technology in `alltech(path)`.

Rows are pathway years. The first column is `year`; technology names are the
remaining columns. If `removenothing` is true, technology columns whose metric
values are all `nothing` are omitted.
"""
function table(p::Path, metric::Function; removenothing::Bool=true)
    years = collect(allyears(p))
    cols = Pair{String,Any}["year" => years]

    for cname in alltech(p)
        values = [metric(p, cname, year) for year in years]
        if !removenothing || !all(isnothing, values)
            push!(cols, cname => values)
        end
    end

    return DataFrame(cols)
end
