function energy = get_energy_buckingham(structure, gulp_cmd, options)
arguments
    structure
    gulp_cmd = "gulp"
    options.keywords = ["optimise", "conp", "qok"]
    options.valence_dict = []
    options.executor = []
end
io = kssolv.analysis.matgenlab.command_line.gulp_caller.GulpIO();
if isa(gulp_cmd, ...
        "kssolv.analysis.matgenlab.command_line.gulp_caller.GulpCaller")
    caller = gulp_cmd;
else
    caller = kssolv.analysis.matgenlab.command_line.gulp_caller. ...
        GulpCaller(gulp_cmd, executor = options.executor);
end
input = io.buckingham_input(structure, options.keywords, ...
    valence_dict = options.valence_dict);
energy = io.get_energy(caller.run(input));
end
