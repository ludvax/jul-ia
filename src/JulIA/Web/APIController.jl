module APIController

# All necessary `using` statements (Genie, UUIDs, Dates, Core modules, Application modules)
# are expected to be handled by the parent `JulIA.Web` module, as defined in `JulIA.jl`.
# This keeps APIController.jl focused on route definitions and controller logic.

# --- Workflow API Routes ---

# GET /api/workflows - List all workflows
route("/api/workflows", method = GET) do
    try
        workflows_list = WorkflowService.list_workflow_files()
        return json(workflows_list)
    catch e
        @error "Failed to list workflows" exception=(e, catch_backtrace())
        # Ensure Genie.Renderer.Json is imported for json()
        # Ensure Genie.HTTPUtils.set_status_code is available or handle status differently if needed.
        # For Genie, returning a Dict with an :error key and setting status in json() is common.
        # response_code = 500 # Internal Server Error
        # return json(Dict("error" => "Failed to retrieve workflows.", "details" => sprint(showerror, e)), status = response_code)
        # Simpler error for now if set_status_code is not directly used or available:
        return json(Dict("error" => "Failed to retrieve workflows: " * sprint(showerror, e)), status = 500)
    end
end

# GET /api/workflows/:id::UUID - Get a specific workflow
route("/api/workflows/:id::UUID", method = GET) do
    workflow_id = params(:id) # params() returns string, Genie auto-parses to UUID for route matching
    workflow_id = params(:id)::UUID # params(:id) is already a UUID due to ::UUID in route definition
    try
        loaded_workflow = WorkflowService.load_workflow_from_file(workflow_id)

        if !isnothing(loaded_workflow)
            return json(loaded_workflow)
        else
            return json(Dict("error" => "Workflow with ID: $workflow_id not found."), status = 404)
        end
    catch e
        # Log the error with workflow_id for context
        @error "Failed to retrieve workflow $workflow_id" exception=(e, catch_backtrace())
        return json(Dict("error" => "Server error while retrieving workflow: " * sprint(showerror, e)), status = 500)
    end
end

# POST /api/workflows - Create a new workflow
route("/api/workflows", method = POST) do
    payload = jsonpayload() # Genie function to get JSON payload as Dict/Array
    local temp_workflow_for_nodes_edges::Workflow
    try
        raw_body = Genie.Requests.rawpayload()
        if isempty(raw_body)
            return json(Dict("error" => "Request body is empty."), status = 400)
        end
        # This parses name, nodes, edges from payload.
        # It might also parse id, created_at, updated_at if client sends them, but we'll override those.
        temp_workflow_for_nodes_edges = JSON3.read(raw_body, Workflow)

        # Basic validation after parsing
        if !isdefined(temp_workflow_for_nodes_edges, :name) || isempty(temp_workflow_for_nodes_edges.name)
             return json(Dict("error" => "Field 'name' is missing or empty in workflow payload."), status = 400)
        end
        if !isdefined(temp_workflow_for_nodes_edges, :nodes) # Assuming empty nodes array is acceptable
             return json(Dict("error" => "Field 'nodes' is missing in workflow payload."), status = 400)
        end
        if !isdefined(temp_workflow_for_nodes_edges, :edges) # Assuming empty edges array is acceptable
             return json(Dict("error" => "Field 'edges' is missing in workflow payload."), status = 400)
        end

    catch ex
        @error "Error processing POST /api/workflows payload: " exception=(ex, catch_backtrace())
        return json(Dict("error" => "Invalid JSON payload or structure for Workflow.", "details" => sprint(showerror, ex)), status = 400)
    end

    # If parsing name, nodes, edges from temp_workflow_for_nodes_edges was successful:
    new_id = uuid4()
    time_now = now(UTC)

    # Construct the final workflow object with server-generated ID and timestamps
    # and data from the (partially) parsed payload
    final_workflow = Workflow(
        new_id,
        temp_workflow_for_nodes_edges.name, # Name from payload
        temp_workflow_for_nodes_edges.nodes,  # Nodes from payload
        temp_workflow_for_nodes_edges.edges,  # Edges from payload
        time_now, # Server-set created_at
        time_now  # Server-set updated_at
    )

    try
        save_success = WorkflowService.save_workflow_to_file(final_workflow)
        if save_success
            # Return the created workflow, now with server-set fields
            return json(final_workflow, status = 201)
        else
            # This case might not be reached if save_workflow_to_file throws an error on failure
            return json(Dict("error" => "Failed to save workflow due to an unspecified error."), status = 500)
        end
    catch e
        @error "Failed to save workflow" exception=(e, catch_backtrace())
        return json(Dict("error" => "Server error while saving workflow.", "details" => sprint(showerror, e)), status = 500)
    end
end

# POST /api/workflows/:id::UUID/execute - Execute a workflow
route("/api/workflows/:id::UUID/execute", method = POST) do
    workflow_id = params(:id)
    workflow_id = params(:id)::UUID
    try
        loaded_workflow = WorkflowService.load_workflow_from_file(workflow_id)

        if isnothing(loaded_workflow)
            return json(Dict("error" => "Workflow with ID: $workflow_id not found. Cannot execute."), status = 404)
        end

        # Execute the workflow
        execution_context = ExecutionEngine.execute_workflow(loaded_workflow)

        # Prepare response from execution_context
        # (ExecutionContext struct has: workflow_id, run_id, data, logs, errors)
        response_data = Dict(
            "workflow_id" => execution_context.workflow_id,
            "run_id" => execution_context.run_id,
            "status" => isempty(execution_context.errors) ? "completed" : "failed",
            "logs_count" => length(execution_context.logs),
            "errors_count" => length(execution_context.errors),
            # Optionally include final data or a summary if it's not too large
            # "final_node_outputs" => execution_context.data
        )

        return json(response_data)

    catch e
        # Log the error with stacktrace for server-side debugging
        @error "Failed to execute workflow $workflow_id" exception=(e, catch_backtrace())
        # Return a generic error message to the client
        return json(Dict("error" => "Failed to execute workflow: " * sprint(showerror, e)), status = 500)
    end
end

# To make these routes active, Genie needs to be running and this routes file loaded.
# Typically, Genie.startup() is called in the main application entry point.

end # module APIController
