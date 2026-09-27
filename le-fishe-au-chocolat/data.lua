local ic_bld = require('lib.icon_builder')
local ls_bld = require('lib.localised_string_builder')

local mod_name = 'le-fishe-au-chocolat'


local do_debug = true 
debug = do_debug and function(input) log('[Debug]['..mod_name..']'..tostring(input)) end or function(_) end
warning = function(input) log('[Warning]['..mod_name..']'..tostring(input)) end
debug('Executing data.lua')

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

--- Converts a given value into a lua string format
---@param val any val to convert to lua string
---@param name string internal
---@param skipnewlines boolean
---@param depth number internal
---@return string
local function luaSerializeTable(val, name, skipnewlines, depth)
    skipnewlines = skipnewlines or false
    depth = depth or 0

    local tmp = string.rep("    ", depth)

    if name then tmp = tmp .. name .. " = " end

    if type(val) == "table" then
        tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")

        for k, v in pairs(val) do
            tmp =  tmp .. luaSerializeTable(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
        end

        tmp = tmp .. string.rep(" ", depth) .. "}"
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

debug('Creating the fish item/capsule')

local fish_prototype = data.raw["capsule"]["raw-fish"]
if fish_prototype == nil then
    warning('Did not find raw-fish, cannot create my items for this mod')
    return
end

-- debug('bioflux: '..luaSerializeTable(data.raw["capsule"]["bioflux"]))
-- debug('bioflux-speed-regen-sticker: '..luaSerializeTable(data.raw["sticker"]["bioflux-speed-regen-sticker"]))
-- debug('bioflux-speed-regen-sticker-behind: '..luaSerializeTable(data.raw["sticker"]["bioflux-speed-regen-sticker-behind"]))



fish_prototype = table.deepcopy(fish_prototype)

local fish_item_name = mod_name .. '-le-fishe'
local fish_icon_location = '__'..mod_name..'__/graphics/le-fishe.png'
local fish_localization = ls_bld.createLocale(mod_name..'.'..'le-fishe'):toLocalisedString()

-- Hardcoded effects. If im feeling motivated, I will turn these into settings
local initial_heal = 20
local heal_per_tick = 1
local interval_ticks = 30
local explosion_probability = .5
local speed_duration_ticks = 60 * 60 * 40 -- 20 min


data:extend({ -- Stickers used for the over-time effects.
    {
        type = 'sticker',
        name = mod_name .. '-speed-regen',
        flags = {'not-on-map'},
        hidden = true,
        single_particle = true,

        use_damage_substitute = false,

        duration_in_ticks = speed_duration_ticks,
        damage_interval = interval_ticks,

        damage_per_tick = {
            amount = -heal_per_tick,
            type = 'fire',
        },
        target_movement_modifier = 2.0,
    }
})


fish_prototype['order'] = fish_prototype['order'] and (fish_prototype['order']..'b') or 'h[raw-fish]b' -- try and put this fish after the base game fish
fish_prototype['stack_size'] = 75

---@type data.CapsulePrototype
local capsule_action = fish_prototype['capsule_action']
---@type data.ProjectileAttackParameters
local attack_parameters = capsule_action['attack_parameters']
---@type data.AmmoType
local ammo_type = attack_parameters['ammo_type']
---@type data.TriggerDeliveryItem
local action = ammo_type['action']
---@type data.TriggerDeliveryItem | data.TriggerDeliveryItem[]
local action_delivery = action['action_delivery']
---@type data.TriggerEffect[]
local target_effects = {
    -- Smaller heal.
    {
        type = 'damage',
        damage = {
            type = 'physical',
            amount = -initial_heal
        },
        use_substitute = false
    },
    {
        type = 'create-sticker',
        sticker = mod_name .. '-speed-regen',
        show_in_tooltip = true,
    },
    -- chance to explode the player.
    {
        type = 'create-explosion',
        entity_name = 'big-explosion',
        probability = explosion_probability,
        affects_target = true,
        show_in_tooltip = true,
    },
    -- other sound
    {
        type = 'play-sound',
        sound = {
            {
                filename = "__" .. mod_name .. '__/audio/le-fishe.ogg',
                volume = 1.0,
                speed = 0.75,
            }
        }
    },
    -- eating sound
    {
        type = 'play-sound',
        sound = {
            {
                filename = "__base__/sound/eat-1.ogg",
                volume = 1.9,
                speed=0.5,
            },
            {
                filename = "__base__/sound/eat-2.ogg",
                volume = 1.9,
                speed=0.5,
            },
            {
                filename = "__base__/sound/eat-3.ogg",
                volume = 1.9,
                speed=0.5,
            },
            {
                filename = "__base__/sound/eat-4.ogg",
                volume = 1.9,
                speed=0.5,
            },
            {
                filename = "__base__/sound/eat-5.ogg",
                volume = 1.9,
                speed=0.5,
            }
        }
    },

}

action_delivery['target_effects'] = target_effects
action['action_delivery'] = action_delivery
ammo_type['action'] = action
attack_parameters['ammo_type'] = ammo_type
capsule_action['attack_parameters'] = attack_parameters
fish_prototype['capsule_action'] = capsule_action

fish_prototype['name'] = fish_item_name
fish_prototype['icon'] = fish_icon_location
fish_prototype['localised_name'] = fish_localization


debug('Fish Im Adding: '..luaSerializeTable(fish_prototype))

data.extend({fish_prototype})



-- Spoil? -> Der Schokoladenfisch
--          -> Il Pesce Cioccolato


-- create recipe
debug('Adding Recipe')

---@type data.RecipePrototype[]
local added_recipes = {}


data.extend({{
    type = "item-subgroup",
    name = mod_name,
    group = "intermediate-products",
    order = "d"
}})

---@type data.RecipePrototype
local recipe = {
    type = "recipe",
    name = fish_item_name,
    localised_name = fish_localization,
    category = "organic-or-chemistry",
    energy_required = 1,
    icon = fish_icon_location,
    icons = nil,
    ingredients = {
        {type = "fluid", name = 'heavy-oil', amount = 13},
        {type = "item", name = 'raw-fish', amount = 1},
    },
    results = {{ type='item', name = fish_item_name, amount = 1 }},
    order=fish_item_name,
    subgroup=mod_name,
    hide_from_stats=false,
    allow_as_intermediate=true,
    allow_productivity = false,
    enabled = false,
}

local water_proto = data.raw['fluid']['water']

local center_icon = ic_bld.makeSingleIconLayer(
    fish_icon_location,
    64,
    1
):toIconBuilder()

local top_left_icon = ic_bld.makeSingleIconLayer(
    water_proto.icon,
    water_proto.icon_size or 64,
    water_proto.icon_mipmaps or 1
):toIconBuilder()

top_left_icon = center_icon:formatTopLeft(top_left_icon)
center_icon:addIconsInfront(top_left_icon)

local wash_icons = center_icon:toIcons()

---@type data.RecipePrototype
local recipe2 = {
    type = "recipe",
    name = mod_name..'wash-le-fishe',
    localised_name = ls_bld.createLocale(mod_name..'.'..'wash-le-fishe'):toLocalisedString(),
    category = "organic-or-chemistry",
    energy_required = 1,
    icon = nil,
    icons = wash_icons,
    ingredients = {
        {type = "fluid", name = 'water', amount = 1000},
        {type = "item", name = fish_item_name, amount = 1},
    },
    results = {{ type='item', name = 'raw-fish', amount = 1 }},
    order=fish_item_name,
    subgroup=mod_name,
    hide_from_stats=false,
    allow_as_intermediate=true,
    enabled = false,
    allow_productivity = false,
}


data.extend({recipe, recipe2})
added_recipes[#added_recipes+1] = recipe
added_recipes[#added_recipes+1] = recipe2



-- add recipes to a technology
debug('Adding Recipe Unlocks To Technologies')

local technologies = {
    'advanced-oil-processing',
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
    -- debug(jsonSerializeTable(temp_tech_name,'temp_tech_name '..index))
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

-- debug(jsonSerializeTable(tech_proto))
data.raw["technology"][science_name] = tech_proto

debug('Done')