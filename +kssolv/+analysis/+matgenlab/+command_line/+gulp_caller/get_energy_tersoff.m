function energy = get_energy_tersoff(structure, gulp_cmd, options)
arguments
    structure
    gulp_cmd = "gulp"
    options.executor = []
end
io = kssolv.analysis.matgenlab.command_line.gulp_caller.GulpIO();
caller = makeGulpCaller(gulp_cmd, options.executor);
energy = io.get_energy(caller.run(io.tersoff_input(structure)));
end

function caller = makeGulpCaller(command, executor)
if isa(command, ...
        "kssolv.analysis.matgenlab.command_line.gulp_caller.GulpCaller")
    caller = command;
else
    caller = kssolv.analysis.matgenlab.command_line.gulp_caller. ...
        GulpCaller(command, executor = executor);
end
end
