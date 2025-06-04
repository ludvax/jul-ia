cd(@__DIR__)
using Pkg
Pkg.activate(".")

function main()
  include(joinpath("src", "GenieApp.jl"))
  GenieApp.main()
end

main()
