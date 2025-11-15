local ic_bld = require('lib.icon_builder')
local ls_bld = require('lib.localised_string_builder')

local mod_name = 'simple-atmosphere-separation'

local delete_symbol = '__base__/graphics/icons/signal/signal-no-entry.png'
local left_right_symbol = '__base__/graphics/icons/arrows/signal-left-right-arrow.png'
local down_right_symbol = '__base__/graphics/icons/arrows/down-right-arrow.png'

local do_debug = true 
debug = do_debug and function(input) log('[Debug]['..mod_name..']'..tostring(input)) end or function(_) end

local function jsonSerializeTable(val, name, depth)
    local indent = '    '
    depth = depth or 0

    local tmp = string.rep(indent, depth)

    if name then tmp = tmp .. '"' .. name .. '": ' end

    if type(val) == "table" then
        tmp = tmp .. "{" .. "\n"
        local add_comma = false
        for k, v in pairs(val) do
            if add_comma then
                tmp = tmp .. "," .. (not skipnewlines and "\n" or "")
            else
                add_comma = true
            end
            tmp =  tmp .. jsonSerializeTable(v, k, depth + 1)
        end
        tmp = tmp .. (not skipnewlines and "\n" or "")

        tmp = tmp .. string.rep(indent, depth) .. "}"
    elseif type(val) == "number" then
        tmp = tmp .. tostring(val)
    elseif type(val) == "string" then
        tmp = tmp .. string.format("%q", val)
    elseif type(val) == "boolean" then
        tmp = tmp .. (val and "true" or "false")
    else
        tmp = tmp .. "\"[unserializable datatype:" .. type(val) .. "]\""
    end

    return tmp
end

---Tries to get the LocalisedString of the fluid
---@param name string fluid data name
---@return data.LocalisedString?
local function get_fluid_localised_name(name)
    local fluid = data.raw["fluid"][name]
    if not fluid then return end
    if fluid.localised_name then
        return fluid.localised_name
    end
    local type_name = "fluid"
    return {type_name.."-name."..name}
end

-- get settings
debug('reading settings')
local setting_add_venting = settings.startup[mod_name.."-add-venting-recipes"].value
local setting_ignore_pressure = settings.startup[mod_name.."-ignore-pressure"].value

-- create recipe subgroup
data.extend({{
    type = "item-subgroup",
    name = mod_name,
    group = "intermediate-products",
    order = "d"
}})


-- get a list of nitrogens and oxygens
debug('getting existing gasses')
local possible_nitrogens = {
    'nitrogen',
    'gas-nitrogen',
    'bi-nitrogen',
}
local possible_oxygens = {
    'oxygen',
    'gas-oxygen',
    'k-oxygen',
}
local existing_nitrogens = {}
local existing_oxygens = {}
for _, name in ipairs(possible_nitrogens) do
    if data.raw["fluid"][name] then
        existing_nitrogens[#existing_nitrogens + 1] = name
    end
end
for _, name in ipairs(possible_oxygens) do
    if data.raw["fluid"][name] then
        existing_oxygens[#existing_oxygens + 1] = name
    end
end

---@type data.RecipePrototype[]
local added_recipes = {}


-- if venting, make venting recipes for all
debug('Adding Venting Recipes')


---@param gas_proto_name string name of the gas prototype
---@param gas_type string what type of gas it is (oxygen/nitrogen)
---@return data.RecipePrototype
function makeVentingRecipe(gas_proto_name,gas_type)
    local gas_proto = data.raw["fluid"][gas_proto_name]
    local delete_icon = ic_bld.makeSingleIconLayer(delete_symbol,64,4):toIconBuilder()

    local icon = ic_bld.getIconsFromProto(gas_proto):copy()
    icon:addIconsbehind(icon:formatScaleRelative(delete_icon,1.0))

    local localised_name = ls_bld.new(get_fluid_localised_name(gas_proto_name))
        :addFallback(ls_bld.createLocale(mod_name..'.'..gas_type))
        :add(ls_bld.createLocale(mod_name..'.'..'venting'))
        :toLocalisedString()

    local recipe = {
        type = "recipe",
        name = gas_proto_name..'-venting',
        localised_name = localised_name,
        category = "chemistry",
        energy_required = 5,
        icon = nil,
        icons = icon:toIcons(),
        ingredients = {
            {type = "fluid", name = gas_proto_name, amount = 1000},
        },
        results = {},
        order='venting-'..gas_type,
        subgroup=mod_name,
        emissions_multiplier = .2,
        overload_multiplier = 5,
        hide_from_stats=true,
        allow_as_intermediate=false,
        enabled = false,
    }
    if not setting_ignore_pressure then
        recipe['surface_conditions'] = {
            {
                property="pressure",
                min=1,
                max=40000
            }
        }
    end
    return recipe
end

if setting_add_venting then
    for _, gas_name in ipairs(existing_nitrogens) do
        local recipe = makeVentingRecipe(gas_name,'nitrogen')
        added_recipes[#added_recipes+1] = recipe
        debug(jsonSerializeTable(recipe))
        data.extend({ recipe })
    end
    for _, gas_name in ipairs(existing_oxygens) do
        local recipe = makeVentingRecipe(gas_name,'oxygen')
        added_recipes[#added_recipes+1] = recipe
        debug(jsonSerializeTable(recipe))
        data.extend({ recipe })
    end

end


-- make atmosphere separation recipe
debug('Adding Atmosphere Separation Recipes')


---@param oxygen_proto_name string
---@param nitrogen_proto_name string
---@return data.RecipePrototype
function makeSeparationRecipe(oxygen_proto_name, nitrogen_proto_name)
    local oxygen_proto = data.raw["fluid"][oxygen_proto_name]
    local nitrogen_proto = data.raw["fluid"][nitrogen_proto_name]

    local single_gas = nil
    local single_gas_name = nil

    if not oxygen_proto then
        single_gas=nitrogen_proto
        single_gas_name=nitrogen_proto_name
    end
    if not nitrogen_proto then
        single_gas=oxygen_proto
        single_gas_name=oxygen_proto_name
    end


    local center_icon = ic_bld.makeSingleIconLayer(left_right_symbol,64,4):toIconBuilder()
    local top_left_icon = ic_bld.makeSingleIconLayer(down_right_symbol,64,4):toIconBuilder()

    local icon = center_icon

    if single_gas then
        local gas_icon = ic_bld.getIconsFromProto(single_gas):copy()
        gas_icon = center_icon:formatBottomRight(gas_icon)
        top_left_icon = center_icon:formatTopLeft(top_left_icon)
        icon = top_left_icon:addIconsInfront(gas_icon)
    else
        local oxygen_icon = ic_bld.getIconsFromProto(oxygen_proto):copy()
        local nitrogen_icon = ic_bld.getIconsFromProto(nitrogen_proto):copy()
        oxygen_icon = top_left_icon:formatCenterLeft(oxygen_icon)
        nitrogen_icon = top_left_icon:formatCenterRight(nitrogen_icon)
        center_icon = top_left_icon:formatCenter(center_icon)
        icon = center_icon:addIconsInfront(oxygen_icon):addIconsInfront(nitrogen_icon)
    end


    local recipe_name = ''
    if single_gas then
        recipe_name = 'atmos-seper-'..single_gas_name
    else
        recipe_name = 'atmos-seper-'..oxygen_proto_name..'-'..nitrogen_proto_name
    end

    local localised_name = ls_bld.createLocale(mod_name..'.'..'atmos-seper'):toLocalisedString()

    local results = {}
    if single_gas then
        results = {{type = "fluid", name = single_gas_name, amount = 1000}}
    else
        results = {
            {type = "fluid", name = nitrogen_proto_name, amount = 780},
            {type = "fluid", name = oxygen_proto_name, amount = 220}
        }
    end


    local recipe = {
        type = "recipe",
        name = recipe_name,
        localised_name = localised_name,
        category = "chemistry",
        energy_required = 5,
        icon = nil,
        icons = icon:toIcons(),
        ingredients = {},
        results = results,
        order=recipe_name,
        subgroup=mod_name,
        emissions_multiplier = -.1,
        allow_as_intermediate=false,
        enabled = false,
    }
    if not setting_ignore_pressure then
        recipe['surface_conditions'] = {
            {
                property="pressure",
                min=700,
                max=2000
            }
        }
    end
    return recipe
end




local num_gasses = #existing_nitrogens
if #existing_oxygens>num_gasses then
    num_gasses = #existing_oxygens
end

for i = 1,num_gasses,1 do
    local recipe = makeSeparationRecipe(existing_oxygens[i],existing_nitrogens[i])
    added_recipes[#added_recipes+1] = recipe
    debug(jsonSerializeTable(recipe))
    data.extend({ recipe })
end

-- add recipes to a technology
debug('Adding Recipe Unlocks To Technologies')

local technologies = {
    'oil-processing',
    'chemical-science-pack',
    'advanced-oil-processing',
    'rocket-silo',
    'automation-science-pack',
}

local science_name = ''

local index = 0
while science_name=='' do
    index = index + 1
    local temp_tech_name = technologies[index]
    debug(jsonSerializeTable(temp_tech_name,'temp_tech_name '..index))
    if temp_tech_name ~= nil then
        local temp_tech = data.raw["technology"][temp_tech_name]
        if temp_tech then
            science_name = temp_tech_name
        end
    else
        science_name = technologies[#technologies]
    end
end

---@type data.TechnologyPrototype
local tech_proto = data.raw["technology"][science_name]
if not tech_proto.effects then
    tech_proto.effects = {}
end
for _, recipe in ipairs(added_recipes) do
    tech_proto.effects[#(tech_proto.effects)+1] = {
        type='unlock-recipe',
        recipe=recipe.name
    }
end

debug(jsonSerializeTable(tech_proto))
data.raw["technology"][science_name] = tech_proto

debug('Done')
