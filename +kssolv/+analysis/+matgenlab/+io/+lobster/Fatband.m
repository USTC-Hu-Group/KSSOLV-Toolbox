classdef Fatband < handle
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %FATBAND Legacy multi-file FATBAND facade.
    properties
        reader
    end
    methods
        function obj = Fatband(filenames, varargin)
            if nargin == 0, return; end
            if isfolder(filenames)
                directory = filenames;
            elseif iscell(filenames)
                directory = fileparts(filenames{1});
            else
                directory = fileparts(char(string(filenames)));
            end
            structure = [];
            if ~isempty(varargin), structure = varargin{end}; end
            obj.reader = kssolv.analysis.matgenlab.io.lobster.future.outputs. ...
                Fatbands(directory, structure);
            obj.reader.process();
        end
        function value = get_bandstructure(obj)
            value = struct("fatbands", {obj.reader.fatbands}, ...
                "efermi", obj.reader.efermi, "kpoints", obj.reader.kpoints, ...
                "structure", obj.reader.structure);
        end
    end
end
