# agent_4.py
import os
from dataclasses import dataclass
from pydantic import BaseModel
from pydantic_ai import Agent, RunContext
from pydantic_ai.models.gemini import GeminiModel
from pydantic_ai.settings import ModelSettings
from pydantic_ai.mcp import MCPServerStdio

REPO_PATH = os.path.abspath(os.path.join(os.getcwd(), "my-git-repo"))  # still needed for git_server
os.makedirs(REPO_PATH, exist_ok=True)
gemini_brain = GeminiModel('gemini-2.5-flash')

# ── 1. BaseModel — structured output the formatting agent must return ─────────
class ChangelogResult(BaseModel):
    version: str
    summary: str
    markdown_content: str

# ── 2. Dynamic Context: typed dependency container (deps_type) ────────────────
@dataclass
class RAGDeps:
    repo_path: str
    changelog_file: str
    style_guide_file: str
    author: str

# Redirect the stdio server path through local proxy bridge
git_server = MCPServerStdio(
    command="python",
    args=["mcp_runtime_bridge.py", "--repository", REPO_PATH],
    env={**os.environ}
)

# ── Phase 1 agent: RAG + formatting (built on agent_3) ───────────────────────
my_agent = Agent(
    model=gemini_brain,
    # TODO: 1. Define the deps_type to be AppDeps for RunContext injection
    #  2. Define the result_type to be ChangelogResult for structured output
    #  3. Define the model_settings to configure the temperature for deterministic output
    system_prompt=(
        "You are a strict release documentation compliance officer. "
        "To produce a changelog entry you MUST follow this sequence:\n"
        "1. Call retrieve_style_guide to fetch the corporate layout template.\n"
        "2. Format the user's raw commits against that template — do not invent facts.\n"
        "3. Call save_changelog with the final pure-markdown output."
    ),
    instructions=(                                  # 4. agent.instructions
        #TODO: 4. Define the agent.instructions to enforce valid Markdown output and commit data integrity
        ""
    ),
)

# ── Tool 1: RAG retrieve — uses RunContext to get style_guide_file path ───────
@my_agent.tool
def retrieve_style_guide(ctx: RunContext[RAGDeps]) -> str:
    """Fetches the corporate changelog style guide from the knowledge base."""
    if not os.path.exists(ctx.deps.style_guide_file):
        raise FileNotFoundError(f"Could not find the compliance file at {ctx.deps.style_guide_file}")
    #TODO: 6. Return the content of the style guide file using the injected deps
    return ""

# ── Tool 2: Persist — uses RunContext to get repo_path and author ─────────────
@my_agent.tool
def save_changelog(ctx: RunContext[RAGDeps], content: str) -> str:
    """Saves the formatted changelog content to disk."""
    os.makedirs(ctx.deps.repo_path, exist_ok=True)
    #TODO: 7. Use the injected deps to write the content to the changelog file
    return f"Changelog saved successfully by {ctx.deps.author}."

# ── Phase 2 agent: git commit via MCP ────────────────────────────────────────
git_agent = Agent(
    model=gemini_brain,
    #TODO: 8. Use the git MCPServerStdio instance to configure the agent's MCP server
    system_prompt=(
        "You are an automated DevOps assistant. Use your available git tools to stage "
        "and commit changes to the repository history. Keep tool arguments clean."
    )
)

async def run_agent_workflow(user_raw_commits: str) -> str:
    repo_path = REPO_PATH
    changelog_file_path = os.path.join(repo_path, "CHANGELOG.md")
    style_guide_file_path = os.path.abspath("./style_guide.txt")

    #TODO: 5. Create an instance of Deps with the appropriate values for repo_path, changelog_file, style_guide_file and author
    deps = ""

    # --- Phase 1: RAG + Markdown Formatting (fully agentic, agent_3 features) ---
    result = await my_agent.run(
        f"Format these raw developer commits into a compliant changelog entry:\n"
        f"{user_raw_commits}",
        deps=deps,
    )
    print(f"Version : {result.data.version}")
    print(f"Summary : {result.data.summary}")

    # --- Phase 2: Git Version Management via MCP ---
    git_prompt = (
        f"The 'CHANGELOG.md' file has been successfully updated on disk.\n"
        f"Please perform exactly two actions using your repository tools:\n"
        f"1. Stage the file 'CHANGELOG.md'.\n"
        f"2. Commit the staged file with a clean, descriptive log message."
    )

    async with git_agent.run_mcp_servers():
        #TODO: 9. Use the git_agent to run the git_prompt and capture the response
        return ""
