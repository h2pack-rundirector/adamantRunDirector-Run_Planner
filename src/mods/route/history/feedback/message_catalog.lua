return {
    biome_depth_unavailable = {
        template = "Room is not valid at this generated depth",
        payload = {},
    },
    encounter_depth_unavailable = {
        template = "Room is not valid at this encounter depth",
        payload = {},
    },
    previous_room_next_tags = {
        template = "Previous planned room does not lead to this room",
        payload = {},
    },
    role_limit = {
        template = "{roleLabel} is already planned",
        payload = {
            roleLabel = {
                fallback = "Room type",
            },
        },
    },
    option_limit = {
        template = "{optionLabel} is already generated",
        payload = {
            optionLabel = {
                fallback = "Room",
            },
        },
    },
    unknown = {
        template = "Selection is not valid",
        payload = {},
    },
}
