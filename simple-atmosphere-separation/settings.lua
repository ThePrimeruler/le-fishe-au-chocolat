local mod_name = 'simple-atmosphere-separation'


data:extend({
-- Startup settings
    {
        type = "bool-setting",
        name = mod_name.."-add-venting-recipes",
        setting_type = "startup",
        default_value = true,
        order = "a-a",
    },
    {
        type = "bool-setting",
        name = mod_name.."-ignore-pressure",
        setting_type = "startup",
        default_value = false,
        order = "a-a",
    }
})