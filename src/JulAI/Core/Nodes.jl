module Nodes

# ExecutionContext is expected to be available from the ExecutionEngine module,
# which is a sibling module within JulAI.Core.
using ..ExecutionEngine: ExecutionContext
# UserCodeSandbox is needed for ConditionalNode's condition_code execution.
using ..SandboxManager.UserCodeSandbox
# Note: UUIDs and Dates are available from JulAI.Core's own `using` statements.

export AbstractNode, WebhookNode, TransformDataNode, ConditionalNode, execute

abstract type AbstractNode end

struct WebhookNode <: AbstractNode
    id::String
    url::String
    method::String
    # Potentially add headers, body template, etc. from config here
end

struct TransformDataNode <: AbstractNode
    id::String
    # This logic will be derived from user_code, likely involving SandboxManager
    # For now, the type is Function; how it gets populated is a later step or discussion.
    transformation_logic::Function
end

# Execute method for WebhookNode
function execute(node::WebhookNode, data::Dict, context::ExecutionContext) # Added context
    # node.id is String. context.logs in ExecutionEngine now expects String for node IDs.
    push!(context.logs, (node.id, "info", "Executing WebhookNode: ID=$(node.id), URL=$(node.url), Method=$(node.method)"))
    # Placeholder for actual HTTP request logic
    # (e.g., using HTTP.jl: HTTP.request(node.method, node.url, headers, body_from_data))
    # For now, return a dummy success or the input data
    return Dict("status" => "success", "message" => "Webhook $(node.id) executed (simulated).", "received_data" => data)
end

# Execute method for TransformDataNode
function execute(node::TransformDataNode, data::Dict, context::ExecutionContext) # Added context
    # node.id is String. context.logs in ExecutionEngine now expects String for node IDs.
    push!(context.logs, (node.id, "info", "Executing TransformDataNode: ID=$(node.id)"))
    # Placeholder for actual data transformation
    # This would involve calling node.transformation_logic(data)
    # Ensure error handling around the call to transformation_logic
    try
        # Call the actual transformation logic function
        transformed_data = node.transformation_logic(data)

        # Log success of transformation if needed (optional)
        # push!(context.logs, (node.id, "debug", "TransformDataNode $(node.id) transformation_logic executed successfully."))

        return transformed_data
    catch e
        # node.id is String. context.logs in ExecutionEngine now expects String for node IDs.
        push!(context.logs, (node.id, "error", "Error during TransformDataNode $(node.id) user logic execution: " * sprint(showerror, e)))
        # Return an error structure or rethrow, depending on desired error handling
        # For now, rethrowing to be caught by the main ExecutionEngine loop
        rethrow(e)
    end
end

struct ConditionalNode <: AbstractNode
    id::String
    condition_code::String # Code Julia qui retourne un Bool
end

# Execute method for WebhookNode
function execute(node::WebhookNode, data::Dict, context::ExecutionContext) # Added context
    # node.id is String. context.logs in ExecutionEngine now expects String for node IDs.
    push!(context.logs, (node.id, "info", "Executing WebhookNode: ID=$(node.id), URL=$(node.url), Method=$(node.method)"))
    # Placeholder for actual HTTP request logic
    # (e.g., using HTTP.jl: HTTP.request(node.method, node.url, headers, body_from_data))
    # For now, return a dummy success or the input data
    return Dict("status" => "success", "message" => "Webhook $(node.id) executed (simulated).", "received_data" => data)
end

# Execute method for TransformDataNode
function execute(node::TransformDataNode, data::Dict, context::ExecutionContext) # Added context
    # node.id is String. context.logs in ExecutionEngine now expects String for node IDs.
    push!(context.logs, (node.id, "info", "Executing TransformDataNode: ID=$(node.id)"))
    # Placeholder for actual data transformation
    # This would involve calling node.transformation_logic(data)
    # Ensure error handling around the call to transformation_logic
    try
        # Call the actual transformation logic function
        transformed_data = node.transformation_logic(data)

        # Log success of transformation if needed (optional)
        # push!(context.logs, (node.id, "debug", "TransformDataNode $(node.id) transformation_logic executed successfully."))

        return transformed_data
    catch e
        # node.id is String. context.logs in ExecutionEngine now expects String for node IDs.
        push!(context.logs, (node.id, "error", "Error during TransformDataNode $(node.id) user logic execution: " * sprint(showerror, e)))
        # Return an error structure or rethrow, depending on desired error handling
        # For now, rethrowing to be caught by the main ExecutionEngine loop
        rethrow(e)
    end
end

# Execute method for ConditionalNode
function execute(node::ConditionalNode, data::Dict{String, Any}, context::ExecutionContext)::Dict{String, Any}
    log_node_id = node.id # String, consistent with ExecutionContext.logs
    push!(context.logs, (log_node_id, "info", "Executing ConditionalNode: ID=$(node.id)"))

    local condition_result::Bool = false # Default value

    if isempty(strip(node.condition_code))
        push!(context.logs, (log_node_id, "warn", "ConditionalNode $(node.id): condition_code is empty. Defaulting to false."))
    else
        function_def_string = "function _conditional_check_(input_data::Dict{String, Any})\n return Bool($(node.condition_code))\nend"

        push!(context.logs, (log_node_id, "debug", "ConditionalNode $(node.id): Compiling condition code: $(function_def_string)"))

        local eval_func::Union{Function, Nothing} = nothing
        try
            # UserCodeSandbox.run_code is now in scope via the new 'using' statement
            eval_func = run_code(function_def_string, Dict{String,Any}(), context)
        catch e
            # Error during compilation in sandbox
            push!(context.logs, (log_node_id, "error", "ConditionalNode $(node.id): Error compiling condition_code via SandboxManager: " * sprint(showerror, e)))
            # context.errors keys are String (node.id of AbstractNode)
            # This assumes ExecutionContext.errors Dict can handle String keys.
            # If ExecutionContext.errors strictly expects UUID keys, this needs adjustment,
            # but we changed logs to use String, so errors should ideally follow.
            # For now, we assume String keys are fine for context.errors.
            context.errors[log_node_id] = e
        end

        if isa(eval_func, Function)
            push!(context.logs, (log_node_id, "debug", "ConditionalNode $(node.id): Condition code compiled. Evaluating..."))
            try
                result_any = eval_func(data) # Pass current node's input data
                if isa(result_any, Bool)
                    condition_result = result_any
                    push!(context.logs, (log_node_id, "info", "ConditionalNode $(node.id): Condition evaluated to: $(condition_result)"))
                else
                    push!(context.logs, (log_node_id, "warn", "ConditionalNode $(node.id): Condition code did not return a Bool (got $(typeof(result_any))). Defaulting to false."))
                    # Optionally record this as an error too
                    context.errors[log_node_id] = TypeError(:ConditionalNode_Execution, "Condition code did not return Bool", result_any)
                end
            catch e
                # Error during execution of the compiled condition
                push!(context.logs, (log_node_id, "error", "ConditionalNode $(node.id): Error executing compiled condition_code: " * sprint(showerror, e)))
                context.errors[log_node_id] = e
            end
        else
            # eval_func is not a function (compilation failed or returned non-function)
            if !haskey(context.errors, log_node_id) # If an error wasn't already logged by run_code's catch block
                push!(context.logs, (log_node_id, "warn", "ConditionalNode $(node.id): Failed to compile condition_code into a function. Defaulting to false."))
            end
        end
    end

    output_data = copy(data) # Pass through input data
    output_data["condition_met"] = condition_result # Add the condition result

    return output_data
end

end # module Nodes
