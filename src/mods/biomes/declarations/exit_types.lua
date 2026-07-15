return {
    ErebusExitDoor = {},
    OceanusExitDoor = {},
    FieldsExitDoor = {},
    CWTartarusExitDoor = {},
    N_OpeningDoor = {},
    EphyraExitDoorReturn = {},
    ShipsExitDoor = {},
    OlympusIndoorExitDoor = {
        constraint = {
            whenSourceHasTag = "Outdoor",
            targetRequiresTag = "Indoor",
        },
    },
    OlympusOutdoorExitDoor = {},
    TyphonExitDoor = {},
    FortressMainDoor = {},
}
