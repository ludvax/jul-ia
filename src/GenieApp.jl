module GenieApp

using Genie # Core Genie framework capabilities.
            # Genie.Router, Genie.Renderer.Html, Genie.Assets are removed as
            # routes and their specific dependencies are now handled in routes.jl
            # or through Genie's automatic loading mechanisms.

function main()
  # Genie.genie() automatically loads routes.jl, initializers, etc.
  Genie.genie(; context = @__MODULE__)
end

# Routes previously here are now in routes.jl and will be loaded automatically.

end # module
