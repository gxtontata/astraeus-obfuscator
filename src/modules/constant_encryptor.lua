local ConstantEncryptor = {}

math.randomseed(os.time())

local function generateRandomName(len)
    len = len or math.random(8, 12)
    local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"
    local name = ""
    -- first char must be a letter or underscore
    local first_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"
    local idx = math.random(1, #first_chars)
    name = first_chars:sub(idx, idx)
    for _ = 2, len do
        local index = math.random(1, #charset)
        name = name .. charset:sub(index, index)
    end
    return name
end

local function xorValues(a, b)
    local r, p = 0, 1
    while a > 0 or b > 0 do
        local x, y = a % 2, b % 2
        if x ~= y then r = r + p end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        p = p * 2
    end
    return r
end

local function makeXorExpression(encoded, key)
    return string.format(
        "(function() local a,b=%d,%d; local r,p=0,1; while a>0 or b>0 do local x,y=a%%2,b%%2; if x~=y then r=r+p end; a=math.floor(a/2); b=math.floor(b/2); p=p*2; end; return r end)()",
        encoded, key
    )
end

local function isAlphaNumUnderscore(ch)
    return ch:match("[%w_]") ~= nil
end

local function isDigit(ch)
    return ch:match("%d") ~= nil
end

function ConstantEncryptor.process(code)
    if type(code) ~= "string" then
        error("Input code must be a string", 2)
    end

    local xorKey = math.random(1000, 65535)
    local parts = {}
    local pos = 1
    local len = #code

    while pos <= len do
        local ch = code:sub(pos, pos)

        -- Skip long strings [[ ... ]]  and [=[ ... ]=]
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
            goto continue
        end

        -- Match numeric literals (integers)
        if isDigit(ch) then
            -- Check if this number is part of a variable name (preceded by alpha/underscore)
            if pos > 1 and isAlphaNumUnderscore(code:sub(pos - 1, pos - 1)) and not isDigit(code:sub(pos - 1, pos - 1)) then
                -- This digit is part of an identifier, skip the rest of the identifier
                local spos = pos
                while pos <= len and isAlphaNumUnderscore(code:sub(pos, pos)) do
                    pos = pos + 1
                end
                table.insert(parts, code:sub(spos, pos - 1))
                goto continue
            end

            -- Read the full number
            local num_start = pos
            while pos <= len and isDigit(code:sub(pos, pos)) do
                pos = pos + 1
            end

            -- Check if it's a float (has a dot followed by digits) or hex - skip those
            if pos <= len and code:sub(pos, pos) == "." and pos + 1 <= len and isDigit(code:sub(pos + 1, pos + 1)) then
                -- It's a float, skip entirely
                pos = pos + 1
                while pos <= len and isDigit(code:sub(pos, pos)) do
                    pos = pos + 1
                end
                table.insert(parts, code:sub(num_start, pos - 1))
                goto continue
            end

            -- Check if followed by alpha/underscore (part of identifier like in 0x notation)
            if pos <= len and isAlphaNumUnderscore(code:sub(pos, pos)) and not isDigit(code:sub(pos, pos)) then
                -- Could be hex like 0xFF or scientific notation, skip
                while pos <= len and isAlphaNumUnderscore(code:sub(pos, pos)) do
                    pos = pos + 1
                end
                table.insert(parts, code:sub(num_start, pos - 1))
                goto continue
            end

            local num_str = code:sub(num_start, pos - 1)
            local num = tonumber(num_str)

            if num and num >= 2 and num == math.floor(num) then
                local encoded = xorValues(num, xorKey)
                local expr = makeXorExpression(encoded, xorKey)
                table.insert(parts, expr)
            else
                table.insert(parts, num_str)
            end
            goto continue
        end

        table.insert(parts, ch)
        pos = pos + 1
        ::continue::
    end

    return table.concat(parts)
end

return ConstantEncryptor
