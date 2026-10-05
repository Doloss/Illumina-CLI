local Parser = {}
Parser.Definitions = {
	{ name = "kick", action = "kick", target = true, usage = "kick <player> [reason]", detail = "Remove a player", confirm = true },
	{ name = "ban", action = "ban", target = true, usage = "ban <player> <duration> <reason>", detail = "Ban a player for a set time", confirm = true },
	{ name = "goto", action = "goto", target = true, usage = "goto <player>", detail = "Teleport to a player" },
	{ name = "fly", action = "setFly", on = true, usage = "fly", detail = "Enable flight" },
	{ name = "unfly", action = "setFly", on = false, usage = "unfly", detail = "Return to the ground" },
	{ name = "inv", action = "setInvisible", on = true, usage = "inv", detail = "Become invisible" },
	{ name = "vis", action = "setInvisible", on = false, usage = "vis", detail = "Become visible" },
	{ name = "kill", action = "kill", target = true, usage = "kill <player>", detail = "Kill a character" },
	{ name = "freeze", action = "setFrozen", target = true, on = true, usage = "freeze <player>", detail = "Hold a character in place" },
	{ name = "unfreeze", action = "setFrozen", target = true, on = false, usage = "unfreeze <player>", detail = "Release a frozen character" },
	{ name = "help", usage = "help", detail = "Show your available commands" },
	{ name = "clear", usage = "clear", detail = "Clear the console" },
}
Parser.Durations = { "1h", "24h", "7d", "30d", "perm" }
local aliases = { slay = "kill", invisible = "inv", visible = "vis" }

function Parser.Words(text)
	local words = {}
	for word in text:gmatch("%S+") do table.insert(words, word) end
	return words
end

function Parser.Find(name)
	name = string.lower(name or "")
	name = aliases[name] or name
	for _, definition in ipairs(Parser.Definitions) do
		if definition.name == name then return definition end
	end
end

function Parser.Allowed(definition, allowed)
	return definition.action == nil or allowed[definition.action] == true
end

function Parser.Resolve(query, roster, selfId)
	query = string.lower(query):gsub("^@", "")
	if query == "all" or query == "others" then return nil, "Use one player at a time" end
	local matches = {}
	for _, player in ipairs(roster) do
		local name = string.lower(player.name)
		if (query == "me" and player.userId == selfId) or name == query or tostring(player.userId) == query then
			return player
		end
		if name:sub(1, #query) == query then table.insert(matches, player) end
	end
	if #matches == 1 then return matches[1] end
	if #matches > 1 then return nil, "That name matches multiple players; type more of the username" end
	return nil, "No matching player in this server (use the F2 panel for offline users)"
end

function Parser.Parse(text, roster, selfId, allowed)
	local words = Parser.Words(text)
	local definition = Parser.Find(words[1])
	if not definition then return nil, "Unknown command. Type help" end
	if not Parser.Allowed(definition, allowed) then return nil, "Your rank cannot do that" end
	local plan = { action = definition.action, name = definition.name, payload = {}, confirm = definition.confirm }
	if definition.on ~= nil then plan.payload.on = definition.on end
	if definition.target then
		if not words[2] then return nil, "Usage: " .. definition.usage end
		local target, message = Parser.Resolve(words[2], roster, selfId)
		if not target then return nil, message end
		plan.userId, plan.targetName = target.userId, target.name
	end
	if definition.name == "ban" then
		local duration = string.lower(words[3] or "")
		if not table.find(Parser.Durations, duration) or not words[4] then
			return nil, "Usage: ban <player> <1h|24h|7d|30d|perm> <reason>"
		end
		plan.payload.duration = duration
		plan.payload.reason = table.concat(words, " ", 4)
	elseif definition.name == "kick" then
		plan.payload.reason = table.concat(words, " ", 3)
	elseif #words > (definition.target and 2 or 1) then
		return nil, "Usage: " .. definition.usage
	end
	return plan
end

function Parser.Suggest(text, roster, selfId, allowed)
	local words = Parser.Words(text)
	local trailing = text:match("%s$") ~= nil
	local index = #words + (trailing and 1 or 0)
	local partial = trailing and "" or string.lower(words[#words] or "")
	local list = {}
	if index <= 1 then
		for _, definition in ipairs(Parser.Definitions) do
			if Parser.Allowed(definition, allowed) and definition.name:sub(1, #partial) == partial then
				table.insert(list, { label = definition.name, detail = definition.detail, text = definition.name .. (definition.target and " " or "") })
			end
		end
	else
		local definition = Parser.Find(words[1])
		if not definition or not Parser.Allowed(definition, allowed) then return list end
		if index == 2 and definition.target then
			if ("me"):sub(1, #partial) == partial then
				table.insert(list, { label = "me", detail = "Your character", text = words[1] .. " me " })
			end
			for _, player in ipairs(roster) do
				local prefix = partial:gsub("^@", "")
				if player.name:lower():sub(1, #prefix) == prefix then
					table.insert(list, { label = player.name, detail = player.displayName or "Player", text = words[1] .. " " .. player.name .. " " })
				end
			end
		elseif index == 3 and definition.name == "ban" then
			for _, duration in ipairs(Parser.Durations) do
				if duration:sub(1, #partial) == partial then
					table.insert(list, { label = duration, detail = duration == "perm" and "Permanent ban" or "Ban duration", text = words[1] .. " " .. words[2] .. " " .. duration .. " " })
				end
			end
		end
	end
	return list
end

return Parser
