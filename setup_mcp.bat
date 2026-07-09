@echo off
echo ========================================================
echo   TFC Financial CRM - Supabase MCP Server Setup
echo ========================================================
echo.
echo [1/3] Adding Supabase MCP server to project config...
echo [INFO] .mcp.json has been written automatically to the project root.
echo.
echo [2/3] Installing Supabase Agent Skills...
call npx skills add supabase/agent-skills
echo.
echo [3/3] Launching Claude MCP interactive authentication...
echo.
echo ========================================================
echo [INSTRUCTION] Select the 'supabase' server, then choose
echo 'Authenticate' to start the login flow in your browser.
echo ========================================================
echo.
pause
npx @anthropic-ai/claude-code /mcp
