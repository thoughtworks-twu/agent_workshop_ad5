# app.py
import streamlit as st
import asyncio
import os
import importlib
import nest_asyncio
import time

# !!! DO NOT MODIFY THIS FILE UNLESS YOU ARE DEBUGGING THE MCP SERVER OR AGENT INTERACTIONS !!!
# This script acts as the main Streamlit application for the AI Agent Laboratory, allowing users to execute different agent modules and inspect the local workspace.
nest_asyncio.apply()

st.set_page_config(page_title="AI Agent Lab", layout="wide")
st.title("AI Agent Laboratory")
st.subheader("Trace the evolution of AI agents")

user_input = st.text_area(
    "Enter raw developer notes or assignment milestone logs here:",
    value="Session 4 handson done: completely integrated Pydantic AI natively with the Model Context Protocol Git infrastructure.",
    height=100
)

st.markdown("### 🎛️ Select an Agent Module to Execute:")
col1, col2, col3, col4 = st.columns(4)

# Keep your col1, col2, col3 blocks exactly as they are...
with col1:
    if st.button("🚀 Run Session 1 (Manual Write)", use_container_width=True):
        import agent_1
        importlib.reload(agent_1)
        with st.spinner("Executing rigid Python file update handler..."):
            output = asyncio.run(agent_1.run_agent_workflow(user_instruction=user_input))
            st.success("Session 1 Complete!")
            st.info(output)

with col2:
    if st.button("🛡️ Run Session 2 (Gemini Writer)", use_container_width=True):
        import agent_2
        importlib.reload(agent_2)
        with st.spinner("Streaming data to technical writer persona..."):
            output = asyncio.run(agent_2.run_agent_workflow(user_instruction=user_input))
            st.success("Session 2 Complete!")
            st.info(output)

with col3:
    if st.button("📦 Run Session 3 (RAG Template)", use_container_width=True):
        import agent_3
        importlib.reload(agent_3)
        with st.spinner("Fetching style guide context and writing via Python..."):
            output = asyncio.run(agent_3.run_agent_workflow(user_raw_commits=user_input))
            st.success("Session 3 Complete!")
            st.info(output)

with col4:
    if st.button("🤖 Run Session 4 (MCP Git Pipeline)", use_container_width=True):
        import agent_4
        importlib.reload(agent_4)
        
        with st.spinner("Invoking local Git MCP Server and recording JSON-RPC traffic..."):
            log_path = os.path.abspath(os.path.join(os.getcwd(), "mcp_traffic.log"))
            
            # Clear log file completely right at start
            with open(log_path, "w", encoding="utf-8") as f:
                f.write("")
            
            try:
                # 1. Execute the tool process pipeline
                output = asyncio.run(agent_4.run_agent_workflow(user_raw_commits=user_input))
                
                st.success("Session 4 Complete!")
                
                # 2. Extract our completely clean, pre-filtered transactions
                mcp_traffic_content = ""
                if os.path.exists(log_path):
                    with open(log_path, "r", encoding="utf-8") as f:
                        mcp_traffic_content = f.read().strip()

                # 3. Render presentation block components cleanly
                if mcp_traffic_content:
                    st.code("### 📡 Recorded MCP Protocol Traffic (JSON-RPC Log File)")
                    st.code(output)
                        
            except Exception as e:
                st.error(f"Execution failed: {str(e)}")
 

# --- 🎯 Isolated Workspace Inspector ---
st.markdown("---")
if "refresh_counter" not in st.session_state:
    st.session_state.refresh_counter = 0

@st.fragment
def render_file_inspector():
    with st.container():
        inspect_header_col, inspect_btn_col = st.columns([5, 1])
        with inspect_header_col:
            st.subheader("🔎 Local Workspace Sandbox Inspector")
        with inspect_btn_col:
            if st.button("🔄 Reload from Disk", use_container_width=True):
                st.session_state.refresh_counter += 1
                st.rerun()
            
        changelog_path = os.path.abspath(os.path.join(os.getcwd(), "my-git-repo", "CHANGELOG.md"))
        st.markdown(f"📂 **Target File Path:** `{changelog_path}`")
        
        if os.path.exists(changelog_path):
            with open(changelog_path, "r", encoding="utf-8") as f:
                st.text_area(label="File Contents", value=f.read(), height=280, key=f"v_{st.session_state.refresh_counter}", disabled=True)
        else:
            st.info("No `CHANGELOG.md` file generated yet.")

render_file_inspector()
