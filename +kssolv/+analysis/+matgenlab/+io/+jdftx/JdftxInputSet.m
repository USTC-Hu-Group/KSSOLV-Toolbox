classdef JdftxInputSet
    %JDFTXINPUTSET Pair of JDFTx input parameters and structure.
    properties
        jdftxinput
        structure
    end
    methods
        function obj = JdftxInputSet(jdftxinput, structure)
            obj.jdftxinput = jdftxinput;
            obj.structure = structure;
        end

        function write_input(obj, directory, options)
            arguments
                obj
                directory
                options.infile = "in"
                options.make_dir (1, 1) logical = true
                options.overwrite (1, 1) logical = true
            end
            directory = string(directory);
            if ~isfolder(directory)
                if options.make_dir
                    mkdir(directory);
                else
                    error("KSSOLV:Matgenlab:JDFTX:MissingDirectory", ...
                        "Directory '%s' does not exist.", directory);
                end
            end
            path = fullfile(directory, string(options.infile));
            if isfile(path) && ~options.overwrite
                error("KSSOLV:Matgenlab:JDFTX:OverwriteDenied", ...
                    "Input file '%s' already exists.", path);
            end
            input = kssolv.analysis.matgenlab.io.jdftx.condense_jdftxinputs( ...
                obj.jdftxinput, ...
                kssolv.analysis.matgenlab.io.jdftx.JDFTXStructure( ...
                obj.structure));
            input.write_file(path);
        end
    end
    methods (Static)
        function obj = from_file(file)
            input = kssolv.analysis.matgenlab.io.jdftx.JDFTXInfile. ...
                from_file(file);
            obj = kssolv.analysis.matgenlab.io.jdftx.JdftxInputSet( ...
                input, input.structure);
        end
    end
end
