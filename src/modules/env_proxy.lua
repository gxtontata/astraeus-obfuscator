local EnvProxy = {}

math.randomseed(os.time())

local GLOBALS_TO_PROXY = {
    "print", "type", "tostring", "tonumber", "error", "assert",
    "pcall", "xpcall", "select", "next", "rawget", "rawset",
    "rawequal", "setmetatable", "getmetatable", "load", "loadstring",
    "require", "pairs", "ipairs", "unpack"
}

local function generateRandomName(len)
    len = len or math.random(8, 12)
    local first_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"
    local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789"
    local name = ""
    local idx = math.random(1, #first_chars)
    name = first_chars:sub(idx, idx)
    for _ = 2, len do
        local index = math.random(1, #charset)
        name = name .. charset:sub(index, index)
    end
    return name
end

local function encodeNameAsEscapes(name)
    local parts = {}
    for i = 1, #name do
        table.insert(parts, "\\" .. string.byte(name, i))
    end
    return table.concat(parts)
end

local function isAlphaNumUnderscore(ch)
    return ch:match("[%w_]") ~= nil
end

local function buildProxyHeader(proxyTableName, globals)
    local lines = {}
    table.insert(lines, "local " .. proxyTableName .. " = {}")
    for _, name in ipairs(globals) do
        local encoded = encodeNameAsEscapes(name)
        table.insert(lines, proxyTableName .. '[\"' .. encoded .. '\"] = ' .. name)
    end
    return table.concat(lines, "\n")
end

function EnvProxy.process(code)
    if type(code) ~= "string" then
        error("Input code must be a string", 2)
    end

    local proxyTableName = generateRandomName(10)

    -- Build a lookup: global name -> encoded key for the proxy table
    local globalEncodedKeys = {}
    for _, name in ipairs(GLOBALS_TO_PROXY) do
        globalEncodedKeys[name] = encodeNameAsEscapes(name)
    end

    -- Build a set for quick lookup
    local globalSet = {}
    for _, name in ipairs(GLOBALS_TO_PROXY) do
        globalSet[name] = true
    end

    -- Tokenize and replace global references
    local parts = {}
    local pos = 1
    local len = #code

    -- Keywords that indicate the next identifier is a definition, not a reference
    local defKeywords = { ["local"] = true, ["function"] = true }

    -- Track the last significant token to detect definitions
    local lastToken = ""

    while pos <= len do
        local ch = code:sub(pos, pos)

        -- Skip long strings [[ ... ]] and [=[ ... ]=]
        if ch == "[" then
            local eq_start = code:match("^%[(=*)%[", pos)
            if eq_start ~= nil then
                local close_pat = "]" .. eq_start .. "]"
                local _, end_pos = code:find(close_pat, pos + 2 + #eq_start, true)
                if end_pos then
                    table.insert(parts, code:sub(pos, end_pos))
                    pos = end_pos + 1
                else
                    table.insert(parts, code:sub(pos))
                    pos = len + 1
                end
                lastToken = ""
                goto continue
            end
        end

        -- Skip block comments --[[ ... ]]
        if ch == "-" and code:sub(pos + 1, pos + 1) == "-" then
            if code:sub(pos + 2, pos + 2) == "[" then
                local eq_start = code:match("^%[(=*)%[", pos + 2)
                if eq_start ~= nil then
                    local close_pat = "]" .. eq_start .. "]"
                    local _, end_pos = code:find(close_pat, pos + 4 + #eq_start, true)
                    if end_pos then
                        table.insert(parts, code:sub(pos, end_pos))
                        pos = end_pos + 1
                    else
                        table.insert(parts, code:sub(pos))
                        pos = len + 1
                    end
                    goto continue
                end
            end
            -- Single-line comment
            local nl = code:find("\n", pos)
            if nl then
                table.insert(parts, code:sub(pos, nl))
                pos = nl + 1
            else
                table.insert(parts, code:sub(pos))
                pos = len + 1
            end
            goto continue
        end

        -- Skip string literals
        if ch == '"' or ch == "'" then
            local quote = ch
            local spos = pos
            pos = pos + 1
            while pos <= len do
                local c = code:sub(pos, pos)
                if c == "\\" then
                    pos = pos + 2
                elseif c == quote then
                    pos = pos + 1
                    break
                else
                    pos = pos + 1
                end
            end
            table.insert(parts, code:sub(spos, pos - 1))
            lastToken = ""
            goto continue
        end

        -- Match identifiers
        if ch:match("[%a_]") then
            local id_start = pos
            while pos <= len and isAlphaNumUnderscore(code:sub(pos, pos)) do
                pos = pos + 1
            end
            local identifier = code:sub(id_start, pos - 1)

            -- Check if this global should be proxied
            if globalSet[identifier] then
                -- Skip if preceded by a definition keyword
                if defKeywords[lastToken] then
                    table.insert(parts, identifier)
                    lastToken = identifier
                    goto continue
                end

                -- Skip if followed by a dot (it's a table access, e.g., `string.format`)
                -- Actually, we check if PRECEDED by a dot (e.g., `math.floor` - floor isn't in our list)
                -- Check if this is part of a dotted expression: preceded by '.'
                if #parts > 0 then
                    -- Look back past whitespace for a dot
                    local lookback = #parts
                    local found_dot = false
                    while lookback >= 1 do
                        local p = parts[lookback]
                        if p:match("^%s+$") then
                            lookback = lookback - 1
                        elseif p == "." then
                            found_dot = true
                            break
                        else
                            break
                        end
                    end
                    if found_dot then
                        table.insert(parts, identifier)
                        lastToken = identifier
                        goto continue
                    end
                end

                -- Skip if followed by a dot (e.g., `string.format` where `string` is not in our list,
                -- but more importantly handles cases like the global being used as a table)
                if pos <= len and code:sub(pos, pos) == "." and pos + 1 <= len and code:sub(pos + 1, pos + 1) ~= "." then
                    table.insert(parts, identifier)
                    lastToken = identifier
                    goto continue
                end

                -- Replace with proxy table lookup
                local encoded_key = globalEncodedKeys[identifier]
                table.insert(parts, proxyTableName .. '[\"' .. encoded_key .. '\"]')
                lastToken = identifier
                goto continue
            end

            table.insert(parts, identifier)
            lastToken = identifier
            goto continue
        end

        -- Skip whitespace but don't update lastToken
        if ch:match("%s") then
            table.insert(parts, ch)
            pos = pos + 1
            goto continue
        end

        -- Other characters
        table.insert(parts, ch)
        lastToken = ch
        pos = pos + 1
        ::continue::
    end

    local transformedCode = table.concat(parts)
    local header = buildProxyHeader(proxyTableName, GLOBALS_TO_PROXY)

    return "do\n" .. header .. "\n" .. transformedCode .. "\nend"
end

return EnvProxy
