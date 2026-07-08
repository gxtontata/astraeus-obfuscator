local StringSplitter = {}

math.randomseed(os.time())

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

local function shuffleArray(arr)
    local shuffled = {}
    for i = 1, #arr do
        shuffled[i] = { index = i, value = arr[i] }
    end
    for i = #shuffled, 2, -1 do
        local j = math.random(1, i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    return shuffled
end

local function splitString(str, quote)
    -- Split the string content into chunks of 2-4 characters
    local chunks = {}
    local pos = 1
    local len = #str
    while pos <= len do
        local remaining = len - pos + 1
        local chunk_size
        if remaining <= 4 then
            chunk_size = remaining
        elseif remaining <= 6 then
            -- Avoid leaving a chunk of 1 character
            chunk_size = math.random(2, math.min(4, remaining - 2))
        else
            chunk_size = math.random(2, 4)
        end
        local chunk = str:sub(pos, pos + chunk_size - 1)
        table.insert(chunks, chunk)
        pos = pos + chunk_size
    end
    return chunks
end

local function escapeForQuote(s, quote)
    -- Escape the string content so it can be safely placed back inside the same quote type
    local result = {}
    for i = 1, #s do
        local c = s:sub(i, i)
        if c == "\\" then
            table.insert(result, "\\\\")
        elseif c == quote then
            table.insert(result, "\\" .. quote)
        elseif c == "\n" then
            table.insert(result, "\\n")
        elseif c == "\r" then
            table.insert(result, "\\r")
        elseif c == "\t" then
            table.insert(result, "\\t")
        elseif c == "\0" then
            table.insert(result, "\\0")
        else
            table.insert(result, c)
        end
    end
    return table.concat(result)
end

local function extractStringContent(code, pos, quote)
    -- Extract raw string content, handling escape sequences
    local content = {}
    local raw = {}
    pos = pos + 1 -- skip opening quote
    while pos <= #code do
        local c = code:sub(pos, pos)
        if c == "\\" then
            -- Keep the raw escape sequence as-is
            if pos + 1 <= #code then
                local next_c = code:sub(pos + 1, pos + 1)
                table.insert(raw, c .. next_c)
                pos = pos + 2
            else
                table.insert(raw, c)
                pos = pos + 1
            end
        elseif c == quote then
            return table.concat(raw), pos + 1
        else
            table.insert(raw, c)
            pos = pos + 1
        end
    end
    return table.concat(raw), pos
end

local function buildSplitExpression(raw_content, quote)
    if #raw_content < 4 then
        return nil -- too short to split
    end

    -- Split into chunks of raw characters (preserving escape sequences)
    local chunks = {}
    local pos = 1
    local len = #raw_content
    local current_chunk = {}
    local current_len = 0

    -- Parse through the raw content accounting for escape sequences as single "chars"
    local chars = {}
    local i = 1
    while i <= len do
        if raw_content:sub(i, i) == "\\" and i + 1 <= len then
            -- Escape sequence counts as one logical char
            table.insert(chars, raw_content:sub(i, i + 1))
            i = i + 2
        else
            table.insert(chars, raw_content:sub(i, i))
            i = i + 1
        end
    end

    if #chars < 4 then
        return nil -- too few logical characters to split
    end

    -- Split logical characters into chunks of 2-4
    local char_chunks = {}
    local ci = 1
    while ci <= #chars do
        local remaining = #chars - ci + 1
        local chunk_size
        if remaining <= 4 then
            chunk_size = remaining
        elseif remaining <= 6 then
            chunk_size = math.random(2, math.min(4, remaining - 2))
        else
            chunk_size = math.random(2, 4)
        end
        local chunk_parts = {}
        for j = ci, ci + chunk_size - 1 do
            table.insert(chunk_parts, chars[j])
        end
        table.insert(char_chunks, table.concat(chunk_parts))
        ci = ci + chunk_size
    end

    -- Create shuffled indices
    local shuffled = shuffleArray(char_chunks)
    local tbl_var = generateRandomName(6)

    -- Build the IIFE
    local expr_parts = {}
    table.insert(expr_parts, "(function() local " .. tbl_var .. "={}")

    -- Insert assignments in shuffled order
    for _, entry in ipairs(shuffled) do
        table.insert(expr_parts, " " .. tbl_var .. "[" .. entry.index .. "]=" .. quote .. entry.value .. quote)
    end

    -- Build concatenation in correct order
    local concat_parts = {}
    for i2 = 1, #char_chunks do
        table.insert(concat_parts, tbl_var .. "[" .. i2 .. "]")
    end
    table.insert(expr_parts, " return " .. table.concat(concat_parts, ".."))
    table.insert(expr_parts, " end)()")

    return table.concat(expr_parts)
end

function StringSplitter.process(code)
    if type(code) ~= "string" then
        error("Input code must be a string", 2)
    end

    local parts = {}
    local pos = 1
    local len = #code

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

        -- Handle string literals
        if ch == '"' or ch == "'" then
            local quote = ch
            local raw_content, end_pos = extractStringContent(code, pos, quote)

            local split_expr = buildSplitExpression(raw_content, quote)
            if split_expr then
                table.insert(parts, split_expr)
            else
                -- String too short, keep original
                table.insert(parts, code:sub(pos, end_pos - 1))
            end
            pos = end_pos
            goto continue
        end

        table.insert(parts, ch)
        pos = pos + 1
        ::continue::
    end

    return table.concat(parts)
end

return StringSplitter
