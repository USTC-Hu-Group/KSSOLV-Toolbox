function [energy, structure] = get_energy_relax_structure_buckingham( ...
        input_structure, gulp_cmd, options)
arguments
    input_structure
    gulp_cmd = "gulp"
    options.keywords = ["optimise", "conp"]
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
input = io.buckingham_input(input_structure, options.keywords, ...
    valence_dict = options.valence_dict);
output = caller.run(input);
energy = io.get_energy(output);
structure = io.get_relaxed_structure(output);
end
