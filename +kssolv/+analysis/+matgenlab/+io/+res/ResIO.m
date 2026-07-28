classdef ResIO
    %RESIO Convenience conversions between RES and matgenlab objects.

    methods (Static)
        function value = structure_from_str(source)
            value = kssolv.analysis.matgenlab.io.res.ResProvider. ...
                from_str(source).structure;
        end

        function value = structure_from_file(filename)
            value = kssolv.analysis.matgenlab.io.res.ResProvider. ...
                from_file(filename).structure;
        end

        function value = structure_to_str(structure)
            writer = kssolv.analysis.matgenlab.io.res.ResWriter(structure);
            value = writer.string;
        end

        function structure_to_file(structure, filename)
            writer = kssolv.analysis.matgenlab.io.res.ResWriter(structure);
            writer.write(filename);
        end

        function value = entry_from_str(source)
            value = kssolv.analysis.matgenlab.io.res.AirssProvider. ...
                from_str(source).entry;
        end

        function value = entry_from_file(filename)
            value = kssolv.analysis.matgenlab.io.res.AirssProvider. ...
                from_file(filename).entry;
        end

        function value = entry_to_str(entry)
            writer = kssolv.analysis.matgenlab.io.res.ResWriter(entry);
            value = writer.string;
        end

        function entry_to_file(entry, filename)
            writer = kssolv.analysis.matgenlab.io.res.ResWriter(entry);
            writer.write(filename);
        end
    end
end
