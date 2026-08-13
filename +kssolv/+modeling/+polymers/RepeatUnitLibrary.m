classdef RepeatUnitLibrary
    %REPEATUNITLIBRARY Built-in and versioned user repeat-unit templates.

    properties (Constant)
        SchemaVersion = 1
    end

    methods (Static)
        function entries = list(query, options)
            arguments
                query {mustBeTextScalar} = ""
                options.storePath {mustBeTextScalar} = ""
            end
            entries = builtIns();
            store = kssolv.modeling.polymers.RepeatUnitLibrary. ...
                loadStore(options.storePath);
            entries = [entries; reshape(store.repeatUnits,[],1)];
            query = lower(string(query));
            if query ~= ""
                entries = entries(arrayfun(@(entry) ...
                    contains(lower(entry.name),query) || ...
                    contains(lower(entry.description),query),entries));
            end
        end

        function entry = get(name, options)
            arguments
                name {mustBeTextScalar}
                options.storePath {mustBeTextScalar} = ""
            end
            entries = kssolv.modeling.polymers.RepeatUnitLibrary.list( ...
                "", storePath=options.storePath);
            which = find(strcmpi(string({entries.name}),string(name)),1);
            if isempty(which)
                error("KSSOLV:Modeling:UnknownRepeatUnit", ...
                    "Unknown repeat unit '%s'.",name);
            end
            entry = activeTemplate(entries(which));
        end

        function saveUser(name, molecule, head, tail, leaving, options)
            arguments
                name {mustBeTextScalar}
                molecule kssolv.analysis.matgenlab.core.IMolecule
                head (1,1) double {mustBeInteger,mustBePositive}
                tail (1,1) double {mustBeInteger,mustBePositive}
                leaving = zeros(1,0)
                options.description {mustBeTextScalar} = "User repeat unit"
                options.storePath {mustBeTextScalar} = ""
                options.overwrite (1,1) logical = false
            end
            leaving = unique(reshape(double(leaving),1,[]),"stable");
            if head>molecule.num_sites || tail>molecule.num_sites || ...
                    head==tail || any(leaving<1) || ...
                    any(leaving>molecule.num_sites) || ...
                    any(ismember([head,tail],leaving))
                error("KSSOLV:Modeling:RepeatUnitHeads", ...
                    "Head, tail, and leaving-atom indices are inconsistent.");
            end
            store = kssolv.modeling.polymers.RepeatUnitLibrary. ...
                loadStore(options.storePath);
            names = string({store.repeatUnits.name});
            existing = find(strcmpi(names,string(name)),1);
            if ~isempty(existing) && ~options.overwrite
                error("KSSOLV:Modeling:RepeatUnitExists", ...
                    "Repeat unit '%s' already exists.",name);
            end
            species = string(cellfun(@(site)site.specie.symbol, ...
                molecule.sites,UniformOutput=false));
            bonds = kssolv.modeling.chemistry.MoleculeDiagnostics. ...
                topology(molecule);
            entry = makeEntry(name,options.description,species, ...
                molecule.cart_coords,bonds,head,tail,leaving,"user");
            if isempty(existing), store.repeatUnits(end+1)=entry;
            else, store.repeatUnits(existing)=entry; end
            writeStore(store,options.storePath);
        end

        function store = loadStore(path)
            path = resolvePath(path);
            store = emptyStore();
            if ~isfile(path), return, end
            decoded = jsondecode(fileread(path));
            if ~isfield(decoded,"schemaVersion") || ...
                    decoded.schemaVersion > ...
                    kssolv.modeling.polymers.RepeatUnitLibrary.SchemaVersion
                error("KSSOLV:Modeling:RepeatUnitSchema", ...
                    "Repeat-unit store schema is unsupported.");
            end
            if isfield(decoded,"repeatUnits") && ~isempty(decoded.repeatUnits)
                values = decoded.repeatUnits;
                if iscell(values), values=[values{:}]; end
                store.repeatUnits = arrayfun(@normalize,values);
            end
        end
    end
end

function entries = builtIns()
entries = [
    makeEntry("PE","Polyethylene",["C","C"], ...
        [0,0,0;1.52,0,0],[1,2,1],1,2,[],"builtin")
    makeEntry("PP","Polypropylene",["C","C","C"], ...
        [0,0,0;1.52,0,0;1.52,1.52,0], ...
        [1,2,1;2,3,1],1,2,[],"builtin")
    makeEntry("PS","Polystyrene", ...
        ["C","C",repmat("C",1,6)],psCoordinates(), ...
        [1,2,1;2,3,1;3,4,1.5;4,5,1.5;5,6,1.5;6,7,1.5; ...
        7,8,1.5;8,3,1.5],1,2,[],"builtin")
    makeEntry("PEO","Polyethylene oxide",["C","C","O"], ...
        [0,0,0;1.52,0,0;2.86,.4,0], ...
        [1,2,1;2,3,1],1,3,[],"builtin")
    makeEntry("PPO","Polypropylene oxide",["C","C","O","C"], ...
        [0,0,0;1.52,0,0;2.86,.4,0;1.52,1.52,0], ...
        [1,2,1;2,3,1;2,4,1],1,3,[],"builtin")
    ];
end

function value = psCoordinates()
angles=pi+(0:5).'*pi/3;
ring=[zeros(6,1),1.40*cos(angles),1.40*sin(angles)];
value=[0,0,0;1.52,0,0;ring+[1.52,2.92,0]];
end

function entry = makeEntry(name,description,species,coordinates,bonds, ...
        head,tail,leaving,source)
entry=struct("name",string(name),"description",string(description), ...
    "species",reshape(string(species),1,[]), ...
    "coordinates",reshape(double(coordinates),[],3), ...
    "bonds",reshape(double(bonds),[],3),"head",double(head), ...
    "tail",double(tail),"leavingAtoms",reshape(double(leaving),1,[]), ...
    "source",string(source),"schemaVersion",1);
end

function entry = activeTemplate(entry)
leaving = reshape(double(entry.leavingAtoms),1,[]);
if isempty(leaving), return, end
keep = setdiff(1:numel(entry.species),leaving,"stable");
map = zeros(1,numel(entry.species)); map(keep)=1:numel(keep);
bonds = double(entry.bonds);
bonds = bonds(~any(ismember(bonds(:,1:2),leaving),2),:);
bonds(:,1:2)=map(bonds(:,1:2));
entry.species=entry.species(keep);
entry.coordinates=entry.coordinates(keep,:);
entry.bonds=bonds;
entry.head=map(entry.head); entry.tail=map(entry.tail);
end

function store = emptyStore()
store=struct("schemaVersion",1,"updatedAt","", ...
    "repeatUnits",repmat(makeEntry("","",strings(1,0), ...
    zeros(0,3),zeros(0,3),1,1,[],"user"),0,1));
end

function entry = normalize(value)
entry=makeEntry(value.name,value.description,value.species, ...
    value.coordinates,value.bonds,value.head,value.tail, ...
    value.leavingAtoms,value.source);
end

function writeStore(store,path)
path=resolvePath(path);
store.schemaVersion=1;
store.updatedAt=string(datetime("now","TimeZone","UTC", ...
    "Format","yyyy-MM-dd'T'HH:mm:ss'Z'"));
kssolv.modeling.internal.AtomicJsonFile.write(path,store, ...
    "KSSOLV:Modeling:RepeatUnitWrite");
end

function path = resolvePath(path)
path=string(path);
if path==""
    path=fullfile(prefdir,"KSSOLV","modeling","repeat-units-v1.json");
end
end
