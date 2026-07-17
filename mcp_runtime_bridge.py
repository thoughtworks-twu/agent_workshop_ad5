# mcp_runtime_bridge.py
import sys
import json
import subprocess
import threading

# !!! DO NOT MODIFY THIS FILE UNLESS YOU ARE DEBUGGING THE MCP SERVER OR AGENT INTERACTIONS !!!
# This script acts as a bridge between the MCP server and the agent, capturing and logging JSON-RPC traffic for debugging and analysis.
LOG_PATH = "mcp_traffic.log"

def log_packet(direction: str, line: str):
    """Parses, filters, and writes ONLY clean tool calls to the markdown log file."""
    clean_line = line.strip()
    if not clean_line:
        return
        
    # 🎯 FIX: Hard-filter layout noise before parsing to guarantee it never slips into the UI
    banned_keywords = ["\"initialize\"", "\"initialized\"", "protocolVersion", "clientInfo", "serverInfo"]
    if any(keyword in clean_line for keyword in banned_keywords):
        return # Drop setup frames immediately

    try:
        payload = json.loads(clean_line)
        
        # Verify it's an active tool manipulation or its explicit system result frame
        method = payload.get("method", "")
        is_tool_call = "tools/" in method
        is_tool_response = "result" in payload

        if is_tool_call or is_tool_response:
            formatted_json = json.dumps(payload, indent=2)
            
            # Write it out cleanly as markdown for the static log file format
            with open(LOG_PATH, "a", encoding="utf-8") as f:
                f.write(f"##### {direction}\n")
                f.write("```json\n")
                f.write(f"{formatted_json}\n")
                f.write("```\n\n")
                f.write(f"{'-'*40}\n\n") # Visual divider line
                f.flush()
    except Exception:
        pass # Discard corrupted frames gracefully

def main():
    server_cmd = [sys.executable, "-m", "mcp_server_git"] + sys.argv[1:]
    
    server_process = subprocess.Popen(
        server_cmd,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=sys.stderr,
        text=True,
        bufsize=1
    )

    def capture_stdout():
        for line in server_process.stdout:
            log_packet("SERVER -> AGENT", line)
            sys.stdout.write(line)
            sys.stdout.flush()

    stdout_thread = threading.Thread(target=capture_stdout, daemon=True)
    stdout_thread.start()

    try:
        for line in sys.stdin:
            log_packet("AGENT -> SERVER", line)
            server_process.stdin.write(line)
            server_process.stdin.flush()
    except (KeyboardInterrupt, BrokenPipeError):
        pass
    finally:
        server_process.terminate()

if __name__ == "__main__":
    main()
