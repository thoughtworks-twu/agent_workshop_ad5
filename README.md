# AI Agent Laboratory
*Trace the evolution of AI agents — from raw Python to MCP-powered Agent*

This workshop walks through four sessions, each building on the previous. You start with a simple Python file writer and end up with a fully autonomous agent that reads a style guide, formats your notes into a changelog, and commits it to git.

The goal isn't just to show you what agents can do. It's to show you *why* each new layer was added, so the progression feels obvious.

---

## What you're building

Each session produces the same end result — a formatted `CHANGELOG.md` — but gets there differently:

- **Session 1** just writes whatever you typed, directly to disk. No AI.
- **Session 2** hands your notes to Gemini and lets it write something polished.
- **Session 3** gives the agent a corporate style guide to follow, so the output is formatted according to the styleguide.
- **Session 4** goes further — a second agent picks up where the first left off and commits the file to git using real MCP tools.

---

## How the architecture grows

```
Session 1
User Input ──► open() ──► CHANGELOG.md

Session 2
User Input ──► Gemini ──► save_changelog tool ──► CHANGELOG.md

Session 3
User Input ──► Agent ──► retrieve_style_guide tool ──► style_guide.txt
                    └──► save_changelog tool ──► CHANGELOG.md

Session 4
User Input ──► formatting_agent ──► retrieve_style_guide tool ──► style_guide.txt
                               └──► save_changelog tool ──► CHANGELOG.md
                                              │
                                              ▼
                                  git_agent ──► MCP Server ──► git stage + commit
```

---

## Project structure

```
multi-agents/
├── streamlit_app.py        # The UI — four buttons, one for each session
├── agent_1.py              # Session 1: plain Python, no AI
├── agent_2.py              # Session 2: Gemini with a save tool
├── agent_3.py              # Session 3: RAG — agent retrieves the style guide itself
├── agent_4.py              # Session 4: two agents, one for formatting, one for git
├── mcp_runtime_bridge.py   # Sits between the agent and the git MCP server, logs traffic to show the MCP traffic
├── style_guide.txt         # The "knowledge base" the RAG agent reads from
└── my-git-repo/
    └── CHANGELOG.md        # Where all agents write their output
```

---

## Before you start

Make sure you have:
- A Google AI Studio API key for Gemini
- `git` on your `PATH`

On macOS, the setup script installs Python 3.11 if it is not already available, then creates the virtual environment and initialises the workshop git repository.

---

## Setup

```bash
# 1. Go to the project root
cd <your-project-folder>

# 2. Run the bootstrap script and enter the requested values
scripts/setup_workshop.sh

# 3. Start the dashboard
scripts/run_workshop.sh
```

Then open [http://localhost:8501](http://localhost:8501).

The setup script:

- Installs Homebrew on macOS only if it is missing
- Installs Python 3.11 with Homebrew only if no Python 3.11+ interpreter is already available
- Creates `.venv` and installs the workshop dependencies
- Creates `my-git-repo/`, runs `git init`, and configures `user.name` and `user.email` from the trainee-provided values
- Saves the API key and trainee git identity in `.env.local` so later runs stay simple

### Useful options

```bash
# Run setup and launch Streamlit immediately
scripts/setup_workshop.sh --run

# Override saved values explicitly
scripts/setup_workshop.sh \
  --api-key "your-api-key-here" \
  --git-name "Your Name" \
  --git-email "you@thoughtworks.com"
```

---

## The sessions

### Session 1 — Manual Write
No AI here. The app takes whatever you typed and dumps it straight into `CHANGELOG.md` with a header. It works, but it's completely rigid — the output is always exactly what you wrote, nothing more. This is the baseline everything else improves on.

---

### Session 2 — Gemini Writer
This is where the AI comes in. The agent has a *technical writer* persona and generates polished changelog copy from your raw notes. But more importantly, it now has a **tool** — `save_changelog` — and it decides when to call it. You're not manually writing the file anymore; the agent does it on its own initiative.

This introduces `@agent.tool_plain`, which is how you register a Python function so the LLM can call it. The function's type hints become the schema, the docstring becomes the description the model reads to know when to use it.

---

### Session 3 — RAG Template Agent
The problem with Session 2 is that Gemini will write in whatever style it feels like. Session 3 fixes that by giving it a corporate style guide to follow — but instead of you injecting the guide into the prompt manually, the **agent retrieves it itself** via a tool.

Two tools now:
- `retrieve_style_guide()` — reads `style_guide.txt`, simulating a RAG fetch
- `save_changelog(content)` — writes the formatted result to disk

The agent calls them in sequence on its own. That's the shift that makes this genuinely agentic — the LLM is deciding what context it needs and going to get it, rather than you pre-loading everything into a prompt.

---

### Session 4 — MCP Git Pipeline
This session splits the work across two agents with different specialisations.

`formatting_agent` does exactly what Session 3's agent does — retrieves the style guide and saves the formatted changelog.

`git_agent` then takes over. It connects to a real `mcp-server-git` instance running as a subprocess and uses it to stage and commit the file. The tools aren't Python functions this time — they're MCP tools called over JSON-RPC, which is a much more powerful and interoperable pattern.

The `mcp_runtime_bridge.py` sits in the middle and logs all the protocol traffic, which gets surfaced in the dashboard so you can see exactly what the agent sent and received.

---

## Concepts worth knowing

**`@agent.tool_plain`** — the simplest way to give an agent a tool. Decorate a plain Python function, and the LLM can call it whenever it decides to. No extra boilerplate.

**`@agent.tool`** — same idea, but the function also receives a `RunContext`, which is useful if your agent has injected dependencies.

**RAG (Retrieval-Augmented Generation)** — instead of baking knowledge into the prompt, you let the agent fetch it at runtime. Session 3 demonstrates this with a flat file; in production you'd point it at a vector database or an API.

**MCP (Model Context Protocol)** — a standardised way for agents to talk to external tool servers over JSON-RPC. The agent doesn't need to know the implementation details of the tools — just their names and schemas.

**`MCPServerStdio`** — spins up an MCP server as a child process and communicates over stdin/stdout. `agent.run_mcp_servers()` manages its lifecycle for the duration of the run.

---

## MCP traffic log

When Session 4 runs, every JSON-RPC frame between `git_agent` and the MCP server is written to `mcp_traffic.log`. Handshake frames are filtered out — you only see the actual tool calls and their responses, which looks something like this:

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "git_add",
    "arguments": { "repo_path": "my-git-repo", "files": ["CHANGELOG.md"] }
  }
}
```

---

## If something goes wrong

**`FileNotFoundError: style_guide.txt`** — make sure you're running `streamlit run` from inside the `multi-agents/` directory, not a parent folder.

**Session 4 git commit fails** — the `my-git-repo` folder to be a git folder before the agent runs. Run the `git init` and setup user.name and user.email.

**`GOOGLE_API_KEY` not found** — export the key in the same terminal session you're running Streamlit from.

**MCP traffic log is empty** — check that `mcp-server-git` is installed and that `mcp_runtime_bridge.py` is in the project root.

**`nest_asyncio` errors** — `nest_asyncio.apply()` needs to be called before any `asyncio.run()` calls. It's already at the top of `streamlit_app.py`, so this usually means a stale import cache — try restarting the Streamlit server.
