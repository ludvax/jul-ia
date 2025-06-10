module ExecutionEngine

# UUIDs and DataStructures are expected to be available from the parent JulIA.Core module.
# Workflow, Node, Edge structs are now from DomainModels.
using ..DomainModels
# AbstractNode and its concrete types (WebhookNode, TransformDataNode) and their execute methods.
using ..Nodes
# UserCodeSandbox for running user-defined functions.
using ..SandboxManager.UserCodeSandbox

export ExecutionContext
export execute_workflow # execute_node and its variants are removed
export determine_execution_order, find_node_by_id, prepare_node_inputs

# Un contexte pour passer les données et l'état pendant l'exécution
mutable struct ExecutionContext
    workflow_id::UUID
    run_id::UUID # ID de l'exécution actuelle
    data::Dict{UUID, Any} # Stocke les sorties de chaque nœud (clé: node_id)
    logs::Vector{Tuple{String, String, String}} # (node_id, level, message) - Changed UUID to String for node_id
    errors::Dict{String, Exception} # Stocke les erreurs par nœud - Changed UUID key to String
    # ... autres informations (variables globales du workflow, etc.)
end

function execute_workflow(workflow::Workflow)
    # DomainModels.Workflow should be accessible for type hinting.
    # ExecutionContext is defined in this module.
    context = ExecutionContext(workflow.id, uuid4(), Dict{UUID, Any}(), [], Dict{UUID, Exception}())

    # 1. Construire le graphe de dépendances et trier topologiquement
    # (Cette partie est complexe et dépend de la manière dont les ports sont gérés)
    # Pour simplifier, supposons un ordre linéaire ou un tri topologique simple.
    execution_order = determine_execution_order(workflow) # Fonction à implémenter

    # 2. Exécuter les nœuds dans l'ordre
    for node_id in execution_order
        node = find_node_by_id(workflow, node_id) # Fonction utilitaire
        if isnothing(node)
            push!(context.logs, (string(node_id), "error", "Node $node_id not found!")) # node_id is UUID here
            # Ensure context.errors is correctly typed for Exception instances
            context.errors[string(node_id)] = KeyError("Node $node_id not found") # Use String key
            continue # Ou arrêter l'exécution
        end

        try
            # Préparer les entrées pour le nœud actuel à partir du contexte
            # Ceci est la partie délicate: mapper les sorties des nœuds précédents
            # connectés par des arêtes aux entrées attendues par le nœud actuel.
            inputs = prepare_node_inputs(node, workflow, context) # Fonction à implémenter

            # --- Refactored Node Execution Logic ---
            concrete_node::Union{AbstractNode, Nothing} = nothing
            node_id_for_log = node.id # UUID for context.logs

            if node.type == "webhook"
                # Ensure URL and method are present in config, provide defaults or error if critical
                url = get(node.config, "url", "")
                method = get(node.config, "method", "GET")
                if isempty(url)
                    # node_id_for_log is UUID, convert to string for logging
                    push!(context.logs, (string(node_id_for_log), "error", "Webhook node $(node.name) (ID: $(node.id)) is missing 'url' in config."))
                    context.errors[string(node.id)] = ArgumentError("Webhook node $(node.name) missing 'url'.") # Use String key
                    continue # Skip to next node
                end
                concrete_node = WebhookNode(string(node.id), url, method)
            elseif node.type == "transform_data"
                # The actual transformation logic for TransformDataNode would ideally be
                # derived from node.user_code via SandboxManager, or a pre-registered function.
                user_code_string = node.user_code # This is Union{String, Nothing}
                default_transform_func = data_input::Dict{String, Any} -> data_input # Identity function
                transformation_to_use::Function = default_transform_func # Initialize with default

                if !isnothing(user_code_string) && !isempty(strip(user_code_string))
                    # Construct the full function definition string
                    func_def_str = "function _dynamically_defined_transform_(data::Dict{String, Any})\n" *
                                   user_code_string *
                                   "\nend"

                    push!(context.logs, (string(node.id), "debug", "Attempting to compile user code for TransformDataNode: $(func_def_str)"))

                    local sandboxed_func_obj = nothing # Ensure it's defined outside try
                    try
                        sandboxed_func_obj = UserCodeSandbox.run_code(func_def_str, Dict{String,Any}(), context) # Pass empty Dict for inputs to run_code, and context
                    catch sandbox_err
                        push!(context.logs, (string(node.id), "error", "Error during SandboxManager.run_code for TransformDataNode: " * sprint(showerror, sandbox_err)))
                        context.errors[string(node.id)] = sandbox_err # Record error for this node; Use String key
                        # transformation_to_use remains default_transform_func
                    end

                    if isa(sandboxed_func_obj, Function)
                        transformation_to_use = sandboxed_func_obj
                        push!(context.logs, (string(node.id), "info", "User-defined transformation compiled successfully for TransformDataNode."))
                    elseif !isnothing(sandboxed_func_obj) # It returned something, but not a function
                        push!(context.logs, (string(node.id), "warn", "User code for TransformDataNode did not result in a compilable function. Result was of type $(typeof(sandboxed_func_obj)). Using default transformation."))
                        context.errors[string(node.id)] = TypeError(:UserCodeSandbox, "User code did not compile to a function", typeof(sandboxed_func_obj)) # Use String key
                        # transformation_to_use remains default_transform_func
                    elseif isnothing(sandboxed_func_obj) && !haskey(context.errors, string(node.id)) # run_code returned nothing without throwing an error that we caught; Use String key for haskey
                        push!(context.logs, (string(node.id), "warn", "User code compilation for TransformDataNode returned nothing. Using default transformation."))
                        # transformation_to_use remains default_transform_func
                    end
                else
                    push!(context.logs, (string(node.id), "info", "User code for TransformDataNode is empty or not provided. Using default identity transformation."))
                end

                concrete_node = TransformDataNode(string(node.id), transformation_to_use)
            elseif node.type == "conditional"
                condition_code_str = get(node.config, "condition_code", "false") # Default to "false"
                if isempty(strip(condition_code_str))
                    # Log using string(node.id) because node.id is UUID here
                    push!(context.logs, (string(node.id), "warn", "Node $(string(node.id)) of type 'conditional' has empty 'condition_code' in config. Defaulting to 'false'."))
                    condition_code_str = "false" # Ensure a valid default expression
                end
                concrete_node = Nodes.ConditionalNode(string(node.id), condition_code_str)
            # Add more elseif blocks here for other concrete node types from core.nodes
            # elseif node.type == "another_node_type"
            #   concrete_node = AnotherNode(...)
            else
                # node_id_for_log is UUID, convert to string for logging
                push!(context.logs, (string(node_id_for_log), "error", "Unknown node type encountered: $(node.type). Cannot execute node $(node.name) (ID: $(node.id))."))
                context.errors[string(node.id)] = TypeError(:execute_node, "Unknown node type", node.type) # Use String key
                continue # Skip to next node
            end

            if !isnothing(concrete_node)
                # Call the execute method from core.nodes module
                # Note: core.nodes.execute methods log with their string ID.
                # This module's direct logs also use string IDs now.
                output = Nodes.execute(concrete_node, inputs, context) # Pass context. Using Nodes.execute for clarity.
                context.data[node.id] = output # Store output using the original UUID key
            else
                # This case should ideally be caught by the unknown node type 'else' block above.
                # If concrete_node is nothing here, it implies a logic error in the if/elseif.
                # node_id_for_log is UUID, convert to string for logging
                push!(context.logs, (string(node_id_for_log), "error", "Failed to create a concrete node for $(node.name) (ID: $(node.id)), type $(node.type)."))
                context.errors[string(node.id)] = ErrorException("Failed to instantiate concrete node for type $(node.type)") # Use String key
                continue # Skip to next node
            end
            # --- End of Refactored Node Execution Logic ---

        catch e
            # This catch block now handles errors from nodes.execute(...) or other issues within the try block
            push!(context.logs, (string(node.id), "error", "Error processing node $(node.name) (ID: $(node.id)): $e")) # node.id is UUID here
            context.errors[string(node.id)] = e # Use String key
            # Décider si l'on continue ou arrête l'exécution en cas d'erreur
            # break
        end
    end

    return context # Retourne le résultat de l'exécution (logs, erreurs, sorties finales)
end

# Obsolete functions execute_node, execute_http_request_node, execute_function_node are removed.

# Stubs for helper functions will be added in the next step. # This comment seems out of place now.

"""
Determines the execution order of nodes in a workflow.
Placeholder implementation: returns nodes in the order they appear in the workflow.
A proper implementation would perform topological sort based on edges.
"""
function determine_execution_order(workflow::Workflow)::Vector{UUID}
    adj = Dict{UUID, Vector{UUID}}()
    in_degree = Dict{UUID, Int}()
    node_map = Dict{UUID, Node}() # For quick lookup if needed, though not strictly for sort

    for node in workflow.nodes
        adj[node.id] = Vector{UUID}()
        in_degree[node.id] = 0
        node_map[node.id] = node
    end

    for edge in workflow.edges
        # Ensure source and target nodes exist (or handle error if necessary)
        if haskey(adj, edge.source) && haskey(in_degree, edge.target)
            push!(adj[edge.source], edge.target)
            in_degree[edge.target] += 1
        else
            # This case should ideally not happen if workflow data is consistent
            # Or, one might choose to ignore edges pointing to/from non-existent nodes
            # For now, let's assume valid edges for simplicity of the sort logic itself
            @warn "Edge $(edge.id) connects non-existent nodes: $(edge.source) -> $(edge.target). Skipping for sort."
        end
    end

    queue = Queue{UUID}()
    for node_id in keys(in_degree)
        if in_degree[node_id] == 0
            enqueue!(queue, node_id)
        end
    end

    topological_order = Vector{UUID}()
    count_visited_nodes = 0

    while !isempty(queue)
        u = dequeue!(queue)
        push!(topological_order, u)
        count_visited_nodes += 1

        # Sort neighbors to ensure deterministic output if multiple valid orders exist
        # This is optional but good for testing and consistency.
        # Requires node_map to fetch node names for sorting if adj stores UUIDs only.
        # For now, we'll use UUIDs directly or skip this deterministic sorting.
        # sorted_neighbors = sort(adj[u], by=neighbor_id -> node_map[neighbor_id].name) # Example if sorting by name

        # Iterate over neighbors (adj[u] should exist as all nodes are in adj)
        if haskey(adj, u)
            for v_id in adj[u] # v_id is the UUID of the neighbor
                if haskey(in_degree, v_id) # Ensure neighbor is a valid node
                    in_degree[v_id] -= 1
                    if in_degree[v_id] == 0
                        enqueue!(queue, v_id)
                    end
                end
            end
        end
    end

    if count_visited_nodes != length(workflow.nodes)
        # Collect nodes part of the cycle or remaining for better error message
        remaining_nodes = [nid for nid in keys(in_degree) if in_degree[nid] > 0]
        error("Workflow has a cycle. Cannot determine execution order. Nodes in cycle or with unmet dependencies: $remaining_nodes")
    end

    return topological_order
end

"""
Finds a node in the workflow by its ID.
Returns the Node object or nothing if not found.
"""
function find_node_by_id(workflow::Workflow, node_id::UUID)::Union{Node, Nothing}
    for node in workflow.nodes
        if node.id == node_id
            return node
        end
    end
    return nothing
end

"""
Prepares the input data for a given node based on the workflow context and edges.
Placeholder implementation: returns an empty dictionary.
A real implementation would look at `workflow.edges` to find connected upstream nodes,
retrieve their outputs from `context.data`, and map them to the current node's input handles.
"""
function prepare_node_inputs(node::Node, workflow::Workflow, context::ExecutionContext)::Dict{String, Any}
    inputs = Dict{String, Any}()
    # Ensure node.id is used for comparison with edge.target
    # Ensure Edge, Node, Workflow, ExecutionContext types are accessible
    # node.id is UUID, convert to string for logging
    # Log entry:
    push!(context.logs, (string(node.id), "debug", "Preparing inputs for node $(node.name) (ID: $(node.id))..."))

    for edge in workflow.edges
        if edge.target == node.id
            source_node_id = edge.source
            target_input_name = edge.target_handle # Name of the input port/key for the current node

            if haskey(context.data, source_node_id)
                source_output = context.data[source_node_id]
                value_to_pass = source_output # Default to passing the whole output

                if !isempty(edge.source_handle) && isa(source_output, Dict)
                    if haskey(source_output, edge.source_handle)
                        value_to_pass = source_output[edge.source_handle]
                        # node.id is UUID, convert to string for logging
                        push!(context.logs, (string(node.id), "debug", "Input '$(target_input_name)' from $(source_node_id).$(edge.source_handle)"))
                    else
                        # Source handle specified, but not found in Dict output of source node
                        # node.id is UUID, convert to string for logging
                        push!(context.logs, (string(node.id), "warn", "Source handle '$(edge.source_handle)' not found in output keys of node $(source_node_id) for input '$(target_input_name)' of node $(node.name). Passing entire output instead."))
                        # value_to_pass remains source_output
                    end
                else
                    # No specific source_handle, or source_output is not a Dict, pass the whole output
                    # node.id is UUID, convert to string for logging
                     push!(context.logs, (string(node.id), "debug", "Input '$(target_input_name)' from $(source_node_id) (direct output)."))
                end

                inputs[target_input_name] = value_to_pass
            else
                # Source node's output not found in context.data
                # This might happen if the source node failed or if execution order is incorrect.
                log_message = "Output for source node $(source_node_id) not found in context.data when preparing input '$(target_input_name)' for node $(node.name) (ID: $(node.id)). This input will be missing."
                # node.id is UUID, convert to string for logging
                push!(context.logs, (string(node.id), "warn", log_message))
                # Optionally, instead of just warning, one could set the input to a special marker or error,
                # or even halt execution depending on strictness. For now, it will be missing.
            end
        end
    end
    # node.id is UUID, convert to string for logging
    push!(context.logs, (string(node.id), "debug", "Inputs prepared for node $(node.name): $(keys(inputs))"))
    return inputs
end

end # module ExecutionEngine
