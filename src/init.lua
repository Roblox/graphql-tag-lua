-- ROBLOX upstream: https://github.com/apollographql/graphql-tag/blob/v2.12.3/src/index.ts
local rootWorkspace = script.Parent
local parseModule = require(rootWorkspace.GraphQL).parse
local GraphQLModule = require(rootWorkspace.GraphQL)
type DocumentNode = GraphQLModule.DocumentNode
type DefinitionNode = GraphQLModule.DefinitionNode
type Location = GraphQLModule.Location
-- ROBLOX fix: add map to luau polyfills
local Map = require(script.luaUtils.Map).Map
local LuauPolyfill = require(rootWorkspace.Parent.Packages.Dev.LuauPolyfill)
local Set = LuauPolyfill.Set
local String = LuauPolyfill.String
local Object = LuauPolyfill.Object
local Array = LuauPolyfill.Array
local console = LuauPolyfill.console

local docCache = Map.new()
local fragmentSourceMap = Map.new()
local printFragmentWarnings = true
local experimentalFragmentVariables = false
local function normalize(string_: string)
	return String.trim(string_:gsub(",+%s+", " "))
end

local function cacheKeyFromLoc(loc: Location)
	return normalize(loc.source.body:sub(loc.start, loc._end))
end

local function processFragments(ast: DocumentNode)
	local seenKeys = Set.new()
	local definitions: DefinitionNode = {}

	for i = 1, #ast.definitions do
		local fragmentDefinition = ast.definitions[i]
		if fragmentDefinition.kind == "FragmentDefinition" then
			local fragmentName = fragmentDefinition.name.value
			local sourceKey = cacheKeyFromLoc(fragmentDefinition.loc)

			-- We know something about this fragment
			local sourceKeySet = fragmentSourceMap:get(fragmentName)
			if sourceKeySet and not sourceKeySet:has(sourceKey) then
				-- this is a problem because the app developer is trying to register another fragment with
				-- the same name as one previously registered. So, we tell them about it.
				if printFragmentWarnings then
					console.warn(
						"Warning: fragment with name "
							.. fragmentName
							.. " already exists.\n"
							.. "graphql-tag enforces all fragment names across your application to be unique; read more about\n"
							.. "this in the docs: http://dev.apollodata.com/core/fragments.html#unique-names"
					)
				end
			elseif not sourceKeySet then
				sourceKeySet = Set.new()
				fragmentSourceMap:set(fragmentName, sourceKeySet)
			end
			sourceKeySet:add(sourceKey)
			if not seenKeys:has(sourceKey) then
				seenKeys:add(sourceKey)
				table.insert(definitions, fragmentDefinition)
			end
		else
			table.insert(definitions, fragmentDefinition)
		end
	end
	return Object.assign({}, ast, { definitions = definitions })
end

local function stripLoc(doc: DocumentNode)
	local workSet = Set.new()
	for i = 1, #workSet do
		local node = workSet[i]
		if node.loc then
			workSet:delete(node.loc)
		end
		for u = 1, #Object.keys(node) do
			local key = Object.keys(node)[u]
			local value = node[tostring(key)]
			if value and typeof(value) == "table" and not Array.isArray(value) then
				workSet:add(value)
			end
		end
	end

	local loc = doc.loc :: Record<string, any>
	local start = nil
	local _end = nil
	if loc then
		local indexOfStart = table.find(loc, start)
		local indexOfEnd = table.find(loc, _end)
		table.remove(loc, indexOfStart)
		table.remove(loc, indexOfEnd)
	end
	return doc
end

local function parseDocument(source: string)
	local cacheKey = normalize(source)

	if not docCache:has(cacheKey) then
		local parsed = parseModule(source, {
			experimentalFragmentVariables,
		})

		if not parsed or parsed.kind ~= "Document" then
			error("Not a valid GraphQL document.")
		end

		docCache:set(
			cacheKey,
			-- check that all "new" fragments inside the documents are consistent with
			-- existing fragments of the same name
			stripLoc(processFragments(parsed))
		)
	end
	return docCache:get(cacheKey)
end

--ROBLOX deviation: we are not dealing with fragmentation
local function gql(literals: string)
	if typeof(literals) == "string" then
		return parseDocument(literals)
	end
	error(
		"graphql-tag-lua does not currently support non-strings or Fragments. Please file an issue or PR if you need this feature added."
	)
end
--[[ export function gql(
  literals: string | readonly string[],
  ...args: any[]
) {
  if (typeof literals === 'string') {
    literals = [literals];
  }
  let result = literals[0];
  args.forEach((arg, i) => {
    if (arg && arg.kind === 'Document') {
      result += arg.loc.source.body;
    } else {
      result += arg;
    }
    result += literals[i + 1];
  });
  return parseDocument(result);
} ]]

function resetCaches()
	docCache:clear()
	fragmentSourceMap:clear()
end

function disableFragmentWarnings()
	printFragmentWarnings = false
end

function enableExperimentalFragmentVariables()
	experimentalFragmentVariables = true
end

function disableExperimentalFragmentVariables()
	experimentalFragmentVariables = false
end

local extras = {
	gql = gql,
	resetCaches = resetCaches,
	disableFragmentWarnings = disableFragmentWarnings,
	enableExperimentalFragmentVariables = enableExperimentalFragmentVariables,
	disableExperimentalFragmentVariables = disableExperimentalFragmentVariables,
}
return {
	default = gql,
	gql = gql,
	resetCaches = extras.resetCaches,
	disableFragmentWarnings = extras.disableFragmentWarnings,
	enableExperimentalFragmentVariables = extras.enableExperimentalFragmentVariables,
	disableExperimentalFragmentVariables = extras.disableExperimentalFragmentVariables,
}
