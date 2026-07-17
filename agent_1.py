# agent_1.py
import os

# Align this path with what the Streamlit File Inspector is searching for
REPO_PATH = os.path.abspath("./my-git-repo")
CHANGELOG_FILE = os.path.join(REPO_PATH, "CHANGELOG.md")

def init_workspace():
    """Initializes the exact repository path expected by the lab dashboard."""
    os.makedirs(REPO_PATH, exist_ok=True)

async def run_agent_workflow(user_instruction: str) -> str:
    """Rigidly writes the raw Streamlit text directly to disk without an AI."""
    init_workspace()

    return f"Status"


# TODO:
#  1. Import DateTime module and update in changelog
#  2. Write a function def to
#       a) Validate if the user instruction is not empty
#       b) Write to the changelog file with a clear header and date of update showing along with user instruction
#  3. Return a success message with the date of update and the user instruction written to the file
#  4. Throw an error if the user instruction is empty and return a failure message