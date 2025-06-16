module MVPWorkflowModels

using JSON3 # Or JSON if JSON3 is not readily available via parent scope. JSON3 is generally preferred.
# UUIDs might be needed if workflow IDs themselves are UUIDs, but MVP spec uses String IDs for nodes.

export WorkflowNode, WorkflowConnection, MVPWorkflow, parse_mvp_workflow_json

struct WorkflowNode
    id::String
    name::String
    type::String
    parameters::Dict{String, Any}
end

struct WorkflowConnection
    from::String # Source node ID
    to::String   # Target node ID
end

struct MVPWorkflow
    name::String
    description::String
    nodes::Vector{WorkflowNode}
    connections::Vector{WorkflowConnection}
    node_map::Dict{String, WorkflowNode} # For quick node lookup by ID
    graph::Dict{String, Vector{String}}  # Adjacency list for execution order
end

"""
Parses a JSON string conforming to the MVP workflow structure into an MVPWorkflow object.
"""
function parse_mvp_workflow_json(json_string::String)::MVPWorkflow
    data = JSON3.read(json_string, Dict) # Read the whole JSON as a Dict

    parsed_nodes = Vector{WorkflowNode}()
    for node_dict in get(data, "nodes", [])
        # Ensure parameters is always a Dict, even if missing or null in JSON
        params = get(node_dict, "parameters", Dict{String, Any}())
        if isnothing(params)
            params = Dict{String, Any}()
        end
        push!(parsed_nodes, WorkflowNode(
            get(node_dict, "id", ""),
            get(node_dict, "name", ""),
            get(node_dict, "type", ""),
            params
        ))
    end

    parsed_connections = Vector{WorkflowConnection}()
    for conn_dict in get(data, "connections", [])
        push!(parsed_connections, WorkflowConnection(
            get(conn_dict, "from", ""),
            get(conn_dict, "to", "")
        ))
    end

    node_map = Dict{String, WorkflowNode}()
    for node in parsed_nodes
        node_map[node.id] = node
    end

    graph = Dict{String, Vector{String}}()
    # Initialize graph keys for all nodes to handle nodes with no outgoing connections
    for node in parsed_nodes
        graph[node.id] = Vector{String}()
    end
    # Populate graph based on connections
    for conn in parsed_connections
        # if !haskey(graph, conn.from) # Already initialized
        #     graph[conn.from] = Vector{String}()
        # end
        if haskey(graph, conn.from) # Ensure 'from' node exists before pushing
             push!(graph[conn.from], conn.to)
        else
            @warn "Connection references a 'from' node ($(conn.from)) that does not exist in the nodes list. Skipping this connection."
        end
    end

    return MVPWorkflow(
        get(data, "name", "Untitled MVP Workflow"),
        get(data, "description", ""),
        parsed_nodes,
        parsed_connections,
        node_map,
        graph
    )
end

end # module MVPWorkflowModels
