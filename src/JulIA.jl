# src/JulIA.jl
module JulIA

# --- Core Module ---
module Core
    # External dependencies for Core modules (if universally needed, or handle in specific files)
    using UUIDs
    using Dates
    using DataStructures # For ExecutionEngine

    # Order matters if files depend on each other's definitions within Core
    include("JulIA/Core/DomainModels.jl") # Defines Workflow, Node, Edge structs
    include("JulIA/Core/MVPWorkflowModels.jl") # Defines MVP-specific workflow structs and parser
    include("JulIA/Core/Nodes.jl")        # Defines AbstractNode, WebhookNode, TransformDataNode, execute for them
    include("JulIA/Core/ExecutionEngine.jl") # Defines ExecutionContext, execute_workflow, helpers
    include("JulIA/Core/SandboxManager.jl")  # Defines UserCodeSandbox

    # Export from Core to make them accessible as JulIA.Core.XYZ
    export DomainModels, MVPWorkflowModels, Nodes, ExecutionEngine, SandboxManager
    # Or export specific structs/functions if preferred for a flatter API from Core
    # e.g., export Workflow, Node, Edge, AbstractNode, WebhookNode, TransformDataNode,
    #               execute, ExecutionContext, execute_workflow, UserCodeSandbox
end # module Core

# --- Application Module ---
module Application
    # External dependencies for Application modules
    using UUIDs
    using Dates
    using JSON3

    # Dependencies on other JulAI modules
    using ..Core.DomainModels # For Workflow, Node, Edge types
    using ..Core.ExecutionEngine # For ExecutionContext (if WorkflowService uses it directly)
                                 # and potentially execute_workflow if called from Application layer
    using ..Core.Nodes # If Application layer manipulates AbstractNode instances directly

    include("JulIA/Application/WorkflowService.jl") # Defines WorkflowService module

    export WorkflowService
end # module Application

# --- Infrastructure Module ---
module Infrastructure
    # Placeholder for future infrastructure components (e.g., database adapters)
    # Example:
    # using ..Core.DomainModels
    # include("Infrastructure/PostgresPersistence.jl")
    # export PostgresPersistence
    include("JulIA/Infrastructure/MVPWorkflowPersistence.jl")
    export MVPWorkflowPersistence # Export the module
end # module Infrastructure

# --- Web Module (API) ---
module Web
    # External dependencies for Web module
    using Genie # This will bring in Router, Requests, Renderer.Json etc.
    using UUIDs # For route params and request/response data
    using Dates   # For timestamps in request/response data

    # Dependencies on other JulAI modules
    using ..Core.DomainModels # For Workflow, Node, Edge structs in payloads/responses
    using ..Core.ExecutionEngine # For execute_workflow and ExecutionContext
    using ..Application.WorkflowService # For CRUD operations on workflows

    include("JulIA/Web/APIController.jl") # Defines APIController module and its routes

    # Typically, you might not export APIController itself, but ensure its routes are loaded
    # and Genie server is started. For now, exporting it is fine for structure.
    export APIController
end # module Web

# --- Main Application ---
# Example of how to make some core types easily accessible from JulAI top level
# using .Core.DomainModels: Workflow, Node, Edge
# using .Core.Nodes: AbstractNode
# using .Core.ExecutionEngine: execute_workflow

function julia_main()::Cint
    try
        println("JulIA Application: Initializing modules...")
        # This structure implies that Genie routes are defined when APIController.jl is included.
        # To start the server, one might call a function from Web or Web.APIController.
        # For example, if APIController had a function like `function start_server() Genie.startup() end`
        # Then: Web.APIController.start_server()

        # Basic test to confirm module loading:
        # This will fail if modules are not exporting these or if paths are wrong.
        # println("Testing module access: \$(Core.DomainModels.Workflow)")
        # println("Testing API controller access: \$(Web.APIController)")
        println("JulIA modules structured. Further setup (like starting Genie) would go here or be called from here.")

    catch err
        Base.showerror(stderr, err)
        Base.show_backtrace(stderr, catch_backtrace())
        return 1
    end
    return 0
end

# Export key modules if you want `using JulIA` to bring them into scope,
# or specific functionalities.
export Core, Application, Web, Infrastructure, julia_main

end # module JulIA
