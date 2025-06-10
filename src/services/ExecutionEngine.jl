module ExecutionEngine

using UUIDs
using ..MyWorkflowApp.Workflows # Provides Node, Edge, Workflow structs
using ..MyWorkflowApp.SandboxManager.UserCodeSandbox # Added for function node execution

export ExecutionContext
export execute_workflow, execute_node, execute_http_request_node, execute_function_node
export determine_execution_order, find_node_by_id, prepare_node_inputs

# Un contexte pour passer les données et l'état pendant l'exécution
mutable struct ExecutionContext
    workflow_id::UUID
    run_id::UUID # ID de l'exécution actuelle
    data::Dict{UUID, Any} # Stocke les sorties de chaque nœud (clé: node_id)
    logs::Vector{Tuple{UUID, String, String}} # (node_id, level, message)
    errors::Dict{UUID, Exception} # Stocke les erreurs par nœud
    # ... autres informations (variables globales du workflow, etc.)
end

function execute_workflow(workflow::Workflow)
    # Ensure MyWorkflowApp.Workflows.Workflow is accessible for type hinting if not already.
    # Ensure ExecutionContext is accessible.
    context = ExecutionContext(workflow.id, uuid4(), Dict{UUID, Any}(), [], Dict{UUID, Exception}())

    # 1. Construire le graphe de dépendances et trier topologiquement
    # (Cette partie est complexe et dépend de la manière dont les ports sont gérés)
    # Pour simplifier, supposons un ordre linéaire ou un tri topologique simple.
    execution_order = determine_execution_order(workflow) # Fonction à implémenter

    # 2. Exécuter les nœuds dans l'ordre
    for node_id in execution_order
        node = find_node_by_id(workflow, node_id) # Fonction utilitaire
        if isnothing(node)
            push!(context.logs, (node_id, "error", "Node $node_id not found!"))
            # Ensure context.errors is correctly typed for Exception instances
            context.errors[node_id] = KeyError("Node $node_id not found")
            continue # Ou arrêter l'exécution
        end

        try
            # Préparer les entrées pour le nœud actuel à partir du contexte
            # Ceci est la partie délicate: mapper les sorties des nœuds précédents
            # connectés par des arêtes aux entrées attendues par le nœud actuel.
            inputs = prepare_node_inputs(node, workflow, context) # Fonction à implémenter

            # Exécuter le nœud en utilisant le NodeExecutor approprié
            output = execute_node(node, inputs, context)

            # Stocker la sortie du nœud dans le contexte
            context.data[node.id] = output

        catch e
            push!(context.logs, (node.id, "error", "Error executing node $(node.name): $e"))
            context.errors[node.id] = e
            # Décider si l'on continue ou arrête l'exécution en cas d'erreur
            # break
        end
    end

    return context # Retourne le résultat de l'exécution (logs, erreurs, sorties finales)
end

# Fonction générique pour exécuter un nœud spécifique
# Utilise la multiple dispatch pour appeler la bonne implémentation
function execute_node(node::Node, inputs::Dict{String, Any}, context::ExecutionContext)
    # Dispatche vers une fonction spécifique basée sur le type du nœud
    # Ex: execute_node_type(node.type, node, inputs, context)
    # Ou mieux, utiliser une approche basée sur des types concrets si possible
    # Pour l'exemple, on va appeler une fonction par type de string
    if node.type == "function"
        return execute_function_node(node, inputs, context)
    elseif node.type == "httpRequest"
        return execute_http_request_node(node, inputs, context)
    # ... autres types de nœuds
    else
        # Ensure Node is accessible for node.type
        error("Unknown node type: $(node.type)")
    end
end

# Exemple d'implémentation pour un nœud HTTP Request (simplifié)
function execute_http_request_node(node::Node, inputs::Dict{String, Any}, context::ExecutionContext)
    # Ensure Node and ExecutionContext are accessible
    url = get(node.config, "url", "")
    method = get(node.config, "method", "GET")
    body = get(inputs, "body", nothing) # L'entrée 'body' pourrait venir d'un nœud précédent

    push!(context.logs, (node.id, "info", "Executing HTTP $method request to $url"))

    # Ici, vous utiliseriez une librairie comme HTTP.jl
    # try
    #     response = HTTP.request(method, url, body=body)
    #     return Dict("status" => response.status, "body" => String(response.body))
    # catch e
    #     push!(context.logs, (node.id, "error", "HTTP request failed: $e"))
    #     throw(e) # Relancer l'erreur pour qu'elle soit capturée par le try/catch principal
    # end
    # Simulation de résultat
    return Dict("status" => 200, "body" => "Simulated response for $url")
end

# Fonction pour exécuter un nœud de type "function"
# Cette fonction sera connectée au SandboxManager dans une étape ultérieure.
function execute_function_node(node::Node, inputs::Dict{String, Any}, context::ExecutionContext)
    if isnothing(node.user_code) || isempty(strip(node.user_code))
        # It's better to also log this error in context if possible, or ensure the calling try/catch in execute_workflow does.
        error("Function node $(node.name) (ID: $(node.id)) requires non-empty user_code.")
    end

    push!(context.logs, (node.id, "info", "Executing user function code for node $(node.name)"))

    # Call the sandboxed execution function
    output = UserCodeSandbox.run_code(node.user_code, inputs, context)

    return output
end

# Stubs for helper functions will be added in the next step.

"""
Determines the execution order of nodes in a workflow.
Placeholder implementation: returns nodes in the order they appear in the workflow.
A proper implementation would perform topological sort based on edges.
"""
function determine_execution_order(workflow::Workflow)::Vector{UUID}
    # Placeholder: Execute nodes in the order they are defined in the workflow.
    # A real implementation would build a graph and perform a topological sort.
    # println("Determining execution order (simple list for now) for workflow: $(workflow.id)") # Example logging
    return [node.id for node in workflow.nodes]
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
    # Placeholder: No inputs are prepared for now.
    inputs = Dict{String, Any}()
    # Example: log that we are trying to prepare inputs
    # push!(context.logs, (node.id, "debug", "Preparing inputs for node $(node.name)... (stub)"))
    return inputs
end

end # module ExecutionEngine
