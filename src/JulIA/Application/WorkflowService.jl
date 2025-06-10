module WorkflowService

using JSON3 # Directly used for JSON3.write/read.

# Note: UUIDs, Dates, and Core module types (Workflow, Node, Edge) are expected to be
# available from the parent JulIA.Application module's scope, as defined in JulIA.jl.
# No explicit `using ..Core.DomainModels` needed here if that's the case.

export save_workflow_to_string, load_workflow_from_string, save_workflow_to_file, load_workflow_from_file, list_workflow_files

const WORKFLOWS_DIR = "workflows_data"

"""
Serializes a Workflow object into a JSON string.
"""
function save_workflow_to_string(workflow::Workflow)::String
    return JSON3.write(workflow)
end

"""
Deserializes a JSON string into a Workflow object.
"""
function load_workflow_from_string(json_string::String)::Workflow
    # JSON3.read will use the type information to construct the Workflow object,
    # automatically handling the nested Node and Edge structs.
    return JSON3.read(json_string, Workflow)
end

# We can add other workflow management functions here later,
# for example, to save to/load from files or a database.

function save_workflow_to_file(workflow::Workflow)::Bool
    mkpath(WORKFLOWS_DIR)
    filepath = joinpath(WORKFLOWS_DIR, "$(workflow.id).json")
    try
        json_string = save_workflow_to_string(workflow)
        write(filepath, json_string)
        # @info "Workflow $(workflow.id) saved to $filepath" # Uncomment for logging
        return true
    catch e
        # @error "Failed to save workflow $(workflow.id) to $filepath" e # Uncomment for logging
        rethrow(e) # Or handle more gracefully
        return false
    end
end

function load_workflow_from_file(id::UUID)::Union{Workflow, Nothing}
    filepath = joinpath(WORKFLOWS_DIR, "$(id).json")
    if isfile(filepath)
        try
            json_string = read(filepath, String)
            return load_workflow_from_string(json_string)
        catch e
            # @error "Failed to load/parse workflow $(id) from $filepath" e # Uncomment for logging
            return nothing
        end
    else
        # @info "Workflow file not found: $filepath" # Uncomment for logging
        return nothing
    end
end

function list_workflow_files()::Vector{Dict{String, Any}}
    mkpath(WORKFLOWS_DIR) # Ensure dir exists before trying to read
    workflow_infos = Vector{Dict{String, Any}}()
    try
        for filename in readdir(WORKFLOWS_DIR)
            if endswith(filename, ".json")
                id_str = replace(filename, ".json" => "")
                try
                    workflow_id = UUID(id_str) # Requires using UUIDs
                    # To get the name, we need to load the workflow
                    wf = load_workflow_from_file(workflow_id)
                    if !isnothing(wf)
                        # Ensure wf.name exists as per Workflow struct
                        push!(workflow_infos, Dict("id" => wf.id, "name" => wf.name, "created_at" => wf.created_at, "updated_at" => wf.updated_at))
                    else
                        # @warn "Could not load workflow for file $filename, skipping." # Uncomment for logging
                    end
                catch e # Error parsing UUID from filename or during loading workflow details
                    # @warn "Could not process file $filename: $e" # Uncomment for logging
                end
            end
        end
    catch e
        # Error reading directory
        # @error "Could not read directory $WORKFLOWS_DIR: $e" # Uncomment for logging
        # Depending on desired behavior, might rethrow or return empty/partial list
    end
    return workflow_infos
end

end # module WorkflowService
