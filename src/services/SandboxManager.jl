module SandboxManager

using ..MyWorkflowApp.ExecutionEngine: ExecutionContext
using ..MyWorkflowApp.Workflows
using UUIDs

export UserCodeSandbox

module UserCodeSandbox
    using ..MyWorkflowApp.ExecutionEngine: ExecutionContext

    global input_data = nothing
    global workflow_context = nothing

    function run_code(code_string::String, inputs::Dict{String, Any}, current_context::ExecutionContext)
        global input_data = inputs
        global workflow_context = current_context
        local result = nothing
        try
            expr = Meta.parse(code_string)
            result = Core.eval(@__MODULE__, expr)
        catch e
            throw(e)
        finally
            global input_data = nothing
            global workflow_context = nothing
        end
        return result
    end

    # --- Function Overrides for Security ---

    const _ERROR_MSG_SANDBOX = "Operation not allowed from sandbox: "

    # File System
    Base.open(path::AbstractString; kwargs...) = error(_ERROR_MSG_SANDBOX * "open file ($(path))")
    Base.open(f::Function, path::AbstractString; kwargs...) = error(_ERROR_MSG_SANDBOX * "open file ($(path)) with function")
    Base.read(io::IO; kwargs...) = error(_ERROR_MSG_SANDBOX * "read from generic IO") # Catches many read variants if they use a generic IO
    Base.read(s::AbstractString; kwargs...) = error(_ERROR_MSG_SANDBOX * "read from file path ($(s))")
    Base.write(io::IO, x) = error(_ERROR_MSG_SANDBOX * "write to generic IO")
    Base.write(s::AbstractString, x) = error(_ERROR_MSG_SANDBOX * "write to file path ($(s))")
    Base.rm(path::AbstractString; kwargs...) = error(_ERROR_MSG_SANDBOX * "rm ($(path))")

    # Code Execution / Loading
    Base.include(mapexpr::Function, M::Module, path::AbstractString) = error(_ERROR_MSG_SANDBOX * "include from path ($(path)) in module $(M)")
    Base.include(M::Module, path::AbstractString) = error(_ERROR_MSG_SANDBOX * "include from path ($(path)) in module $(M)")
    Base.include(path::AbstractString) = error(_ERROR_MSG_SANDBOX * "include from path ($(path))")

    # Prevent nested eval within the sandbox
    Base.eval(m::Module, x) = error(_ERROR_MSG_SANDBOX * "nested eval in module $(m)")
    Base.eval(x) = error(_ERROR_MSG_SANDBOX * "nested eval")

    # Process Control & External Commands
    Base.run(cmd::Cmd; kwargs...) = error(_ERROR_MSG_SANDBOX * "run external command ($(cmd))")
    Base.exit(code::Integer=0) = error(_ERROR_MSG_SANDBOX * "exit with code ($(code))")
    Base.exit() = error(_ERROR_MSG_SANDBOX * "exit") # Ensure this variant is also caught

    # FFI (Foreign Function Interface)
    Base.ccall(fptr, rt, at, av...) = error(_ERROR_MSG_SANDBOX * "ccall")
    Base.ccall(fptr::Ptr, rt, at, av...) = error(_ERROR_MSG_SANDBOX * "ccall with Ptr")
    # Add more specific ccall signatures if necessary, though a general block is a start.

    # --- End Function Overrides ---
end

end # module SandboxManager
