module DomainModels

# UUIDs and Dates are expected to be available from the parent JulIA.Core module.

export Node, Edge, Workflow # Export the structs so they can be used by other modules

struct Node
    id::UUID
    type::String # Ex: "httpRequest", "function", "databaseQuery"
    name::String # Nom affiché dans l'UI
    position::Dict{String, Float64} # Position dans l'UI (pour ReactFlow)
    config::Dict{String, Any} # Paramètres de configuration spécifiques au nœud
    user_code::Union{String, Nothing} # Code Julia sous forme de string
end

struct Edge
    id::UUID
    source::UUID # ID du nœud source
    source_handle::String # Port de sortie du nœud source
    target::UUID # ID du nœud cible
    target_handle::String # Port d'entrée du nœud cible
end

struct Workflow
    id::UUID
    name::String
    nodes::Vector{Node}
    edges::Vector{Edge}
    created_at::DateTime
    updated_at::DateTime
end

end # module DomainModels
