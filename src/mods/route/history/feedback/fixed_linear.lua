local common = (... or {}).common

return common.createAdapter({
    renderRecord = common.nextChoiceRenderRecord,
})
