module WorkflowService

using JSON3
# Assuming MyWorkflowApp is the root module for the src directory,
# and Workflows is a submodule within it.
using ..MyWorkflowApp.Workflows

export save_workflow_to_string, load_workflow_from_string

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

end # module WorkflowService
