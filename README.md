# Julia n8n-like Workflow App with ReactFlow

This project aims to create a web application similar to n8n, using Julia with the GenieFramework for the backend and ReactFlow for the frontend.

## Project Structure

```
.
├── app/                  # Genie app specific files (controllers, models etc. - currently minimal)
│   ├── layouts/
│   └── resources/
├── config/               # Genie configuration files
├── frontend/             # ReactFlow frontend application
│   ├── app.js            # ReactFlow main JavaScript
│   ├── index.html        # Main HTML file for frontend
│   └── style.css         # Basic CSS for frontend
├── public/               # Default public assets folder for Genie (currently unused for frontend)
├── src/                  # Julia source code
│   └── GenieApp.jl       # Main Genie application module
├── test/                 # Test files
│   ├── app_tests.jl      # Tests for application endpoints
│   └── runtests.jl       # Main test runner script
├── bootstrap.jl          # Script to initialize and start the Genie application
├── LICENSE               # Project license
├── Project.toml          # Julia project dependencies
├── routes.jl             # Genie route definitions
└── README.md             # This file
```

## Prerequisites

- Julia (version 1.x recommended)

## Setup and Installation

1.  **Clone the repository:**
    ```bash
    git clone <repository_url>
    cd <repository_directory>
    ```

2.  **Install Julia dependencies:**
    Open the Julia REPL in the project directory and run:
    ```julia
    using Pkg
    Pkg.activate(".")
    Pkg.instantiate()
    ```
    This will install Genie.jl and other packages specified in . The  package is also needed for running tests. If it's not automatically installed as a sub-dependency of Genie, you might need to add it explicitly: .

## Running the Application

1.  **Start the Genie backend server:**
    In your terminal, from the root of the project directory, run:
    ```bash
    julia bootstrap.jl
    ```
    This will start the Genie server, typically on .

2.  **Access the frontend:**
    Open your web browser and navigate to:
    [http://localhost:8000](http://localhost:8000)

    You should see a basic ReactFlow diagram.

## Running Tests

**Important**: Ensure the Genie server is running before executing the tests.

1.  **Start the Genie server** (if not already running) as described in "Running the Application".

2.  **Run the tests:**
    In a new terminal, from the root of the project directory, execute:
    ```bash
    julia test/runtests.jl
    ```
    This will run the test suite defined in .

## Development Notes

- The frontend currently uses CDN links for React, ReactDOM, and ReactFlow for simplicity. For a more robust setup, consider using a JavaScript package manager (npm/yarn) and bundling the frontend assets.
- Genie's routing is configured in  at the root of the project.
- Static assets for the frontend (, ) are served directly by Genie, as defined in the routes.
