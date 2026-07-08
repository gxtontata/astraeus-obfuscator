local DummyModule = {}

function DummyModule.process(code)
    return code .. "\n_G.__astraeus_dummy_module_ran = true"
end

return DummyModule
