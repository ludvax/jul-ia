module APIController

# Dependencies from JulIA.Web parent scope: Genie (Router, Requests, Renderer.Json), UUIDs, Dates
# Explicit using for modules specific to this controller's new MVP logic:
using ..Core.MVPWorkflowModels
using ..Infrastructure.MVPWorkflowPersistence
using ..Core.ExecutionEngine # Still needed for execute_mvp_workflow
using JSON3 # For JSON3.isvalid and direct parsing if needed. Genie.Requests.jsonpayload() also uses it.

# --- MVP Database Setup ---
const MVP_DB_PATH = "mvp_workflows.sqlite" # Or make it configurable
try
    MVPWorkflowPersistence.init_db(MVP_DB_PATH)
    @info "MVP Workflow Database initialized at: $(MVP_DB_PATH)"
catch e
    @error "Failed to initialize MVP Workflow Database!" exception=(e, catch_backtrace())
    # Depending on policy, might rethrow or exit if DB is critical.
    # For now, server will start but DB operations might fail.
end

# --- Workflow API Routes (Adapted for MVP) ---

# GET /api/workflows - List all workflows
route("/api/workflows", method = GET) do
    try
        workflows = MVPWorkflowPersistence.list_workflows(MVP_DB_PATH)
        return json(workflows)
    catch e
        @error "Failed to list MVP workflows" exception=(e, catch_backtrace())
        return json(Dict("error" => "Failed to retrieve workflows: " * sprint(showerror, e)), status = 500)
    end
end

# GET /api/workflows/:id::String - Get a specific workflow
route("/api/workflows/:id::String", method = GET) do # Changed to :id::String
    try
        workflow_id_str = params(:id) # Already a string
        details = MVPWorkflowPersistence.load_workflow_details(MVP_DB_PATH, workflow_id_str)

        if !isnothing(details)
            # Return name, description, and the full JSON definition string
            return json(Dict(
                "id" => details.id,
                "name" => details.name,
                "description" => details.description,
                "json_definition" => details.json_definition, # Send the raw JSON string
                "created_at" => details.created_at
            ))
        else
            return json(Dict("error" => "MVP Workflow with ID: $workflow_id_str not found."), status = 404)
        end
    catch e
        @error "Failed to retrieve MVP workflow $workflow_id_str" exception=(e, catch_backtrace())
        return json(Dict("error" => "Failed to retrieve workflow: " * sprint(showerror, e)), status = 500)
    end
end

# POST /api/workflows - Create a new workflow
route("/api/workflows", method = POST) do
    try
        payload_dict = jsonpayload() # Reads JSON body into a Dict. Relies on Content-Type: application/json.
        name = get(payload_dict, "name", "Untitled MVP Workflow")
        description = get(payload_dict, "description", "")

        # For MVP, we expect the full workflow definition (nodes, connections) in the payload.
        # We'll save the raw JSON string of the *entire payload* as the definition.
        raw_json_payload = Genie.Requests.rawpayload()

        if isempty(raw_json_payload) || !JSON3.isvalid(raw_json_payload)
             return json(Dict("error" => "Request body is empty or not valid JSON."), status = 400)
        end

        # Optional: Validate if it can be parsed into our MVPWorkflow structure.
        # try
        #     MVPWorkflowModels.parse_mvp_workflow_json(raw_json_payload)
        # catch parse_err
        #     @warn "MVP Workflow JSON validation failed during create" exception=(parse_err, catch_backtrace())
        #     return json(Dict("error" => "Invalid workflow structure in JSON payload.", "details" => sprint(showerror, parse_err)), status = 400)
        # end

        new_id = string(uuid4()) # Generate ID here using UUIDs from parent scope
        save_success = MVPWorkflowPersistence.save_workflow(MVP_DB_PATH, new_id, name, description, raw_json_payload)

        if save_success
            return json(Dict("id" => new_id, "name" => name, "description" => description, "message" => "Workflow saved successfully."), status = 201)
        else
            return json(Dict("error" => "Failed to save workflow to database."), status = 500)
        end
    catch e
        @error "Error processing POST /api/workflows for MVP" exception=(e, catch_backtrace())
        # Check if JSON3.JSONException needs specific import or if it's a subtype of a general Exception
        # For now, using a generic check. If JSON3 is used by jsonpayload, its exceptions might propagate.
        return json(Dict("error" => "Invalid request or server error: " * sprint(showerror, e)), status = 500) # Simplified error status
    end
end

# POST /api/workflows/:id::String/execute - Execute a workflow
route("/api/workflows/:id::String/execute", method = POST) do # Changed to :id::String
    try
        workflow_id_str = params(:id)
        workflow_details = MVPWorkflowPersistence.load_workflow_details(MVP_DB_PATH, workflow_id_str)

        if isnothing(workflow_details)
            return json(Dict("error" => "MVP Workflow with ID: $workflow_id_str not found. Cannot execute."), status = 404)
        end

        json_definition = workflow_details.json_definition
        # This parse step also validates the structure needed for execution
        parsed_mvp_workflow = MVPWorkflowModels.parse_mvp_workflow_json(json_definition)

        # MVP spec doesn't specify initial data via API, so pass empty Dict
        # execute_mvp_workflow is from Core.ExecutionEngine, available via JulIA.Web's using statement
        execution_result = ExecutionEngine.execute_mvp_workflow(parsed_mvp_workflow, Dict{String,Any}())

        return json(execution_result) # execute_mvp_workflow returns Dict with status and context

    catch e
        @error "Failed to execute MVP workflow $workflow_id_str" exception=(e, catch_backtrace())
        return json(Dict("error" => "Failed to execute workflow: " * sprint(showerror, e)), status = 500)
    end
end

# To make these routes active, Genie needs to be running and this routes file loaded.
# Typically, Genie.startup() is called in the main application entry point.

end # module APIController
