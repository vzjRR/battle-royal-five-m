-- EVENT STUDIO test runner.  Usage: lua5.4 tests/run.lua [filter]
-- Each test file runs in its own process (fresh global state).

local root = arg[0]:match('^(.*)/tests/run%.lua$') or '.'
local filter = arg[1]

if arg[1] == '--one' then
    -- child mode: run a single file
    _G.Sim = { root = root }
    local file = arg[2]
    local H = dofile(root .. '/tests/lib/harness.lua')
    _G.T = H
    dofile(file)
    local passed, failed = H.run(file)
    io.stdout:write(('__RESULT__ %d %d\n'):format(passed, failed))
    os.exit(failed == 0 and 0 or 1)
end

local files = {}
local p = io.popen(("ls -1 '%s'/tests/test_*.lua"):format(root))
for line in p:lines() do
    if not filter or line:find(filter, 1, true) then files[#files + 1] = line end
end
p:close()

local totalP, totalF = 0, 0
local lua = arg[-1] or 'lua5.4'
for _, f in ipairs(files) do
    print(('\27[1m%s\27[0m'):format(f:match('tests/(.*)$')))
    local h = io.popen(("'%s' '%s/tests/run.lua' --one '%s' 2>&1"):format(lua, root, f))
    local out = h:read('a')
    h:close()
    local pp, ff = out:match('__RESULT__ (%d+) (%d+)')
    io.write((out:gsub('__RESULT__ %d+ %d+\n?', '')))
    if not pp then
        print('  \27[31m✗ crashed\27[0m')
        totalF = totalF + 1
    else
        totalP, totalF = totalP + tonumber(pp), totalF + tonumber(ff)
    end
end
print(('\n%d passed, %d failed'):format(totalP, totalF))
os.exit(totalF == 0 and 0 or 1)
