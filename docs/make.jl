using Documenter
using Pathway

makedocs(
    sitename="Pathway.jl",
    authors="Guillaume KRIVTCHIK, OECD Nuclear Energy Agency (OECD-NEA)",
    modules=[Pathway],
    checkdocs=:exports,
    repo="https://github.com/oecd-nea/Pathway.jl/blob/{commit}{path}#L{line}",
    format=Documenter.HTML(
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://oecd-nea.github.io/Pathway.jl/",
        repolink="https://github.com/oecd-nea/Pathway.jl",
        edit_link="main",
    ),
    pages=[
        "Home" => "index.md",
        "Tutorial" => "tutorial.md",
        "Pathway Concepts" => "concepts.md",
        "API Reference" => "api.md",
    ],
)

if get(ENV, "CI", "false") == "true"
    deploydocs(
        repo="github.com/oecd-nea/Pathway.jl.git",
        devbranch="main",
    )
end
