classdef PMGDir < handle
    %PMGDIR Lazy, recursive parser-backed view of a calculation directory.

    properties (SetAccess = private)
        path string
    end

    properties (Access = private)
        files
    end

    methods
        function obj = PMGDir(dirname)
            obj.path = string(java.io.File(char(dirname)).getCanonicalPath());
            if ~isfolder(obj.path)
                error("KSSOLV:Matgenlab:PMGDir:MissingDirectory", ...
                    "Directory '%s' does not exist.", obj.path);
            end
            obj.reset();
        end

        function reset(obj)
            listing = dir(fullfile(obj.path, "**", "*"));
            listing = listing(~[listing.isdir]);
            obj.files = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            prefixLength = strlength(obj.path) + 2;
            for index = 1:numel(listing)
                absolute = string(fullfile( ...
                    listing(index).folder, listing(index).name));
                relative = extractAfter(absolute, prefixLength - 1);
                relative = replace(relative, filesep, "/");
                obj.files(char(relative)) = [];
            end
        end

        function value = get_files_by_name(obj, name)
            matched = string(obj.files.keys);
            matched = matched(contains(matched, string(name)));
            value = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            for index = 1:numel(matched)
                key = char(matched(index));
                value(key) = obj.get(key);
            end
        end

        function value = get(obj, item)
            item = replace(string(item), filesep, "/");
            key = char(item);
            if ~isKey(obj.files, key)
                error("KSSOLV:Matgenlab:PMGDir:NotFound", ...
                    "%s not found in %s.", item, obj.path);
            end
            value = obj.files(key);
            if ~isempty(value), return; end
            filename = fullfile(obj.path, replace(item, "/", filesep));
            value = obj.parseFile(filename, item);
            obj.files(key) = value;
        end

        function value = length(obj), value = double(obj.files.Count); end
        function value = count(obj), value = double(obj.files.Count); end
        function value = keys(obj), value = string(obj.files.keys); end
        function value = isKey(obj, item)
            value = isKey(obj.files, char(string(item)));
        end
        function value = contains(obj, item), value = obj.isKey(item); end

        function value = char(obj)
            value = sprintf("PMGDir(%s)", obj.path);
        end

        function value = string(obj), value = string(char(obj)); end

        function varargout = subsref(obj, reference)
            if strcmp(reference(1).type, "()") || ...
                    strcmp(reference(1).type, "{}")
                if numel(reference(1).subs) ~= 1
                    error("KSSOLV:Matgenlab:PMGDir:Index", ...
                        "PMGDir indexing accepts exactly one filename.");
                end
                value = obj.get(reference(1).subs{1});
                if numel(reference) > 1
                    value = builtin("subsref", value, reference(2:end));
                end
                varargout{1} = value;
            else
                [varargout{1:nargout}] = builtin( ...
                    "subsref", obj, reference);
            end
        end
    end

    methods (Access = private)
        function value = parseFile(~, filename, item)
            package = "kssolv.analysis.matgenlab.io.vasp.";
            upperName = upper(string(item));
            if contains(upperName, "INCAR")
                value = feval(package + "Incar.from_file", filename);
            elseif contains(upperName, "POSCAR") || ...
                    contains(upperName, "CONTCAR")
                value = feval(package + "Poscar.from_file", filename);
            elseif contains(upperName, "KPOINTS") || ...
                    contains(upperName, "IBZKPT")
                value = feval(package + "Kpoints.from_file", filename);
            elseif contains(upperName, "POTCAR")
                value = feval(package + "Potcar.from_file", filename);
            elseif contains(upperName, "VASPRUN")
                value = feval(package + "Vasprun", filename);
            elseif contains(upperName, "OUTCAR")
                value = feval(package + "Outcar", filename);
            elseif contains(upperName, "OSZICAR")
                value = feval(package + "Oszicar", filename);
            elseif contains(upperName, "CHGCAR")
                value = feval(package + "Chgcar.from_file", filename);
            elseif contains(upperName, "WAVECAR")
                value = feval(package + "Wavecar", filename);
            elseif contains(upperName, "WAVEDER")
                value = feval(package + "Waveder.from_binary", filename);
            elseif contains(upperName, "LOCPOT")
                value = feval(package + "Locpot.from_file", filename);
            elseif contains(upperName, "XDATCAR")
                value = feval(package + "Xdatcar", filename);
            elseif contains(upperName, "EIGENVAL")
                value = feval(package + "Eigenval", filename);
            elseif contains(upperName, "PROCAR")
                value = feval(package + "Procar", filename);
            elseif contains(upperName, "ELFCAR")
                value = feval(package + "Elfcar.from_file", filename);
            elseif contains(upperName, "DYNMAT")
                value = feval(package + "Dynmat", filename);
            elseif contains(upperName, "WSWQ")
                value = feval(package + "WSWQ.from_file", filename);
            else
                warning("KSSOLV:Matgenlab:PMGDir:NoParser", ...
                    "No parser defined for %s. Contents are returned as a string.", ...
                    item);
                value = string( ...
                    kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                    readText(filename));
            end
        end
    end
end
