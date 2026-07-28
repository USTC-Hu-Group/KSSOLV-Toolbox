classdef PseudoParser < handle
    properties (SetAccess = private)
        parsed_paths string = strings(0, 1)
        wrong_paths string = strings(0, 1)
    end
    methods
        function obj = PseudoParser()
        end
        function pseudos = scan_directory(obj, dirname, exclude_exts, exclude_fnames)
            if nargin < 3, exclude_exts = strings(0, 1); end
            if nargin < 4, exclude_fnames = strings(0, 1); end
            exclude_exts = string(exclude_exts); exclude_fnames = string(exclude_fnames);
            for i = 1:numel(exclude_exts)
                if ~startsWith(exclude_exts(i), "."), exclude_exts(i) = "." + exclude_exts(i); end
            end
            entries = dir(dirname); pseudos = {};
            for i = 1:numel(entries)
                if entries(i).isdir || startsWith(entries(i).name, ".") || ismember(string(entries(i).name), exclude_fnames)
                    continue
                end
                [~, ~, ext] = fileparts(entries(i).name);
                if ismember(string(ext), exclude_exts)
                    continue
                end
                path = string(fullfile(entries(i).folder, entries(i).name));
                try
                    pseudo = obj.parse(path);
                    pseudos{end + 1} = pseudo; %#ok<AGROW>
                    obj.parsed_paths(end + 1) = path;
                catch
                    obj.wrong_paths(end + 1) = path;
                end
            end
        end
        function desc = read_ppdesc(~, filename)
            if endsWith(lower(string(filename)), ".xml")
                error("KSSOLV:Matgenlab:Abinit:PseudoParse", ...
                    "XML pseudopotentials do not use an ABINIT text descriptor.");
            end
            lines = splitlines(string(fileread(filename)));
            if numel(lines) < 3, desc = []; return; end
            values = str2double(regexp(char(lines(3)), '[-+]?\d+', 'match'));
            if numel(values) < 2, desc = []; return; end
            code = values(1);
            names = containers.Map([1,2,3,4,6,7,8,10], ...
                {"TM","GTH","HGH","Teter","FHI","PAW_abinit_text","ONCVPSP","HGHK"});
            if ~isKey(names, code)
                error("KSSOLV:Matgenlab:Abinit:PseudoParse", ...
                    "Unsupported ABINIT pspcod %d.", code);
            end
            if code == 7, pseudoType = "PAW"; else, pseudoType = "NC"; end
            desc = struct("pspcod", code, "name", string(names(code)), ...
                "psp_type", pseudoType, "format", "");
            if code == 7
                tokens = split(strtrim(extractBefore(lines(4), ":")));
                desc.format = tokens(1);
            end
        end
        function pseudo = parse(obj, filename)
            path = string(filename);
            if ~isfile(path)
                error("KSSOLV:Matgenlab:Abinit:PseudoParse", "File does not exist: %s", path);
            end
            if endsWith(lower(path), ".xml")
                pseudo = kssolv.analysis.matgenlab.io.abinit.PawXmlSetup(path); return
            end
            desc = obj.read_ppdesc(path);
            if isempty(desc)
                error("KSSOLV:Matgenlab:Abinit:PseudoParse", "Cannot identify pseudopotential %s.", path);
            end
            switch desc.name
                case "FHI"
                    header = kssolv.analysis.matgenlab.io.abinit.NcAbinitHeader.fhi_header(path, desc);
                case {"HGH", "HGHK"}
                    header = kssolv.analysis.matgenlab.io.abinit.NcAbinitHeader.hgh_header(path, desc);
                case "GTH"
                    header = kssolv.analysis.matgenlab.io.abinit.NcAbinitHeader.gth_header(path, desc);
                case {"TM", "Teter"}
                    header = kssolv.analysis.matgenlab.io.abinit.NcAbinitHeader.tm_header(path, desc);
                case "ONCVPSP"
                    header = kssolv.analysis.matgenlab.io.abinit.NcAbinitHeader.oncvpsp_header(path, desc);
                case "PAW_abinit_text"
                    header = kssolv.analysis.matgenlab.io.abinit.PawAbinitHeader.paw_header(path, desc);
                otherwise
                    error("KSSOLV:Matgenlab:Abinit:PseudoParse", "Unsupported pseudopotential format.");
            end
            if desc.psp_type == "NC"
                pseudo = kssolv.analysis.matgenlab.io.abinit.NcAbinitPseudo(path, header);
            else
                pseudo = kssolv.analysis.matgenlab.io.abinit.PawAbinitPseudo(path, header);
            end
        end
    end
end
