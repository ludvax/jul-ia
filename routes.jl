using Genie.Router
using Genie.Renderer.Html # For serve_static_file, can also be Genie.Assets

# Serve index.html from the frontend directory at the root
route("/") do
  serve_static_file("frontend/index.html")
end

# Serve static assets from the frontend directory
route("/app.js") do
    serve_static_file("frontend/app.js", content_type = "application/javascript")
end

route("/style.css") do
    serve_static_file("frontend/style.css", content_type = "text/css")
end
