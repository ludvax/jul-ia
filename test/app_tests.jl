using Test
using HTTP

# These tests assume the Genie server is running (e.g., via 'julia bootstrap.jl')
# For a fully automated test suite, you'd start/stop the server programmatically.

@testset "Frontend Serving Tests" begin
    @testset "Root Page" begin
        try
            response = HTTP.get("http://localhost:8000/")
            @test response.status == 200
            body = String(response.body)
            @test occursin("<title>Workflow App</title>", body)
            @test occursin("<div id=\"root\">", body)
            @test occursin("ReactFlow", body) # Check if ReactFlow script is mentioned
        catch e
            @warn "Could not connect to server for testing Root Page. Run 'julia bootstrap.jl' first. Error: $e"
            @test false # Fail test if server is not connectable
        end
    end

    @testset "Static Assets" begin
        try
            # Test for app.js
            response_js = HTTP.get("http://localhost:8000/app.js")
            @test response_js.status == 200
            @test occursin("ReactFlow", String(response_js.body)) # Basic check for content
            @test HTTP.header(response_js, "Content-Type") == "application/javascript"

            # Test for style.css
            response_css = HTTP.get("http://localhost:8000/style.css")
            @test response_css.status == 200
            @test occursin("body {", String(response_css.body)) # Basic check for content
            @test HTTP.header(response_css, "Content-Type") == "text/css"
        catch e
            @warn "Could not connect to server for testing Static Assets. Run 'julia bootstrap.jl' first. Error: $e"
            @test false # Fail test if server is not connectable
        end
    end
end

println("App tests defined in test/app_tests.jl. Run with 'julia test/runtests.jl' after starting the server.")
