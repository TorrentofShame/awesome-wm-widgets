

local utils = {}

local function split(string_to_split, separator)
    if separator == nil then separator = "%s" end
    local t = {}

    for str in string.gmatch(string_to_split, "([^".. separator .."]+)") do
        table.insert(t, str)
    end

    return t
end

function utils.extract_sinks_and_sources(pacmd_output)
    local sinks = {}
    local sources = {}
    local default_sink
    local default_source
    local device
    local properties
    local ports
    local in_sink = false
    local in_source = false
    local in_device = false
    local in_properties = false
    local in_ports = false
    for line in pacmd_output:gmatch("[^\r\n]+") do
        if string.match(line, 'source%(s%) available.') then
            in_sink = false
            in_source = true
        end
        if string.match(line, 'sink%(s%) available.') then
            in_sink = true
            in_source = false
        end

        if string.match(line, 'default:') then
            if in_sink then
                default_sink = line:match(': (.+)')
            else
                default_source = line:match(': (.+)')
            end
        end

        if string.match(line, 'Sink #') or string.match(line, 'Source #') then
            in_device = true
            in_properties = false
            device = {
                id = line:match('#(%d+)'),
                is_default = false
                --is_default = string.match(line, '*') ~= nil
            }
            if in_sink then
                table.insert(sinks, device)
            elseif in_source then
                table.insert(sources, device)
            end
        end

        if string.match(line, '^\tProperties:') then
            in_device = false
            in_properties = true
            properties = {}
            device['properties'] = properties
        end

        if string.match(line, 'Ports:') then
            in_device = false
            in_properties = false
            in_ports = true
            ports = {}
            device['ports'] = ports
        end

        if string.match(line, 'Active Port:') then
            in_device = false
            in_properties = false
            in_ports = false
            device['active_port'] = line:match(': (.+)'):gsub('<',''):gsub('>','')
        end

        if in_device then
            local t = split(line, ': ')
            local key = t[1]:gsub('\t+', ''):lower()
            local value = t[2]:gsub('^<', ''):gsub('>$', '')
            device[key] = value

            -- check for defaults when name is set
            if key == 'name' then
                local default_cmp = in_sink and default_sink or default_source
                if value == default_cmp then
                    device.is_default = true
                end
            end
        end

        if in_properties then
            local t = split(line, '=')
            local key = t[1]:gsub('\t+', ''):gsub('%.', '_'):gsub('-', '_'):gsub(':', ''):gsub("%s+$", "")
            local value
            if t[2] == nil then
                value = t[2]
            else
                value = t[2]:gsub('"', ''):gsub("^%s+", ""):gsub(' Analog Stereo', '')
            end
            properties[key] = value
        end

        if in_ports then
            local t = split(line, ': ')
            local key = t[1]
            if key ~= nil then
                key = key:gsub('\t+', '')
            end
            ports[key] = t[2]
        end
    end

    return sinks, sources
end

return utils
