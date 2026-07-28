classdef GaussianInput
    %GAUSSIANINPUT Gaussian input model and parser.
    %
    % Native MATLAB implementation of pymatgen-core v2026.7.24.

    properties (Access=private)
        molecule_
    end

    properties
        charge
        spin_multiplicity
        title string
        functional
        basis_set
        route_parameters
        input_parameters
        link0_parameters
        dieze_tag string
        gen_basis
    end

    properties (Dependent,SetAccess=private)
        molecule
    end

    methods
        function obj=GaussianInput(mol,charge,spinMultiplicity,title, ...
                functional,basisSet,routeParameters,inputParameters, ...
                link0Parameters,diezeTag,genBasis)
            if nargin<1,mol=[];end
            if nargin<2,charge=[];end
            if nargin<3,spinMultiplicity=[];end
            if nargin<4,title="";end
            if nargin<5,functional="HF";end
            if nargin<6,basisSet="6-31G(d)";end
            if nargin<7,routeParameters=[];end
            if nargin<8,inputParameters=[];end
            if nargin<9,link0Parameters=[];end
            if nargin<10,diezeTag="#P";end
            if nargin<11,genBasis=[];end
            obj.molecule_=mol;
            if isa(mol,"kssolv.analysis.matgenlab.core.Molecule")
                if isempty(charge),obj.charge=mol.charge;
                else,obj.charge=double(charge);end
                electrons=mol.charge+mol.nelectrons-obj.charge;
                if isempty(spinMultiplicity)
                    obj.spin_multiplicity=1+mod(round(electrons),2);
                else
                    obj.spin_multiplicity=double(spinMultiplicity);
                    if mod(round(electrons+obj.spin_multiplicity),2)~=1
                        error("KSSOLV:Matgenlab:GaussianInput:ChargeSpin", ...
                            "Charge of %g and spin multiplicity of %g is " + ...
                            "not possible for this molecule.", ...
                            obj.charge,obj.spin_multiplicity);
                    end
                end
                if strlength(string(title))==0,title=mol.formula;end
            else
                obj.charge=charge;obj.spin_multiplicity=spinMultiplicity;
                if strlength(string(title))==0,title="Restart";end
            end
            obj.title=string(title);
            obj.functional=obj.optionalString(functional);
            obj.basis_set=obj.optionalString(basisSet);
            obj.route_parameters=obj.normalizeMap(routeParameters);
            obj.input_parameters=obj.normalizeMap(inputParameters);
            obj.link0_parameters=obj.normalizeMap(link0Parameters);
            diezeTag=string(diezeTag);
            if strlength(diezeTag)==0,diezeTag="#P";end
            if ~startsWith(diezeTag,"#"),diezeTag="#"+diezeTag;end
            obj.dieze_tag=diezeTag;
            obj.gen_basis=genBasis;
            if ~isempty(genBasis),obj.basis_set="Gen";end
        end

        function value=get.molecule(obj),value=obj.molecule_;end

        function value=get_zmatrix(obj)
            if ~isa(obj.molecule_, ...
                    "kssolv.analysis.matgenlab.core.Molecule")
                error("KSSOLV:Matgenlab:GaussianInput:Molecule", ...
                    "A Molecule is required to construct a Z-matrix.");
            end
            value=string(obj.molecule_.get_zmatrix());
        end

        function value=get_cart_coords(obj)
            if ~isa(obj.molecule_, ...
                    "kssolv.analysis.matgenlab.core.Molecule")
                error("KSSOLV:Matgenlab:GaussianInput:Molecule", ...
                    "A Molecule is required for Cartesian coordinates.");
            end
            lines=strings(obj.molecule_.num_sites,1);
            for index=1:obj.molecule_.num_sites
                site=obj.molecule_.sites{index};
                lines(index)=sprintf("%s %.6f %.6f %.6f", ...
                    site.species_string,site.coords);
            end
            value=strjoin(lines,newline);
        end

        function value=to_str(obj,cartCoords)
            if nargin<2,cartCoords=false;end
            output=strings(0,1);
            if obj.link0_parameters.Count>0
                output(end+1)=obj.mapToString( ...
                    obj.link0_parameters,newline);
            end
            functionalText=strtrim(string(obj.functional));
            basis=strtrim(string(obj.basis_set));
            if ismissing(functionalText),functionalText="";end
            if ismissing(basis),basis="";end
            if strlength(functionalText)>0&&strlength(basis)>0
                method=" "+functionalText+"/"+basis;
            else
                method=strtrim(" "+functionalText+basis,"right");
                if strlength(method)>0,method=" "+method;end
            end
            route=obj.mapToString(obj.route_parameters," ");
            output=[output;obj.dieze_tag+method+" "+route; ...
                "";obj.title;""];
            if isempty(obj.charge),chargeText="";
            else,chargeText=sprintf("%.0f",obj.charge);end
            if isempty(obj.spin_multiplicity),spinText="";
            else,spinText=sprintf(" %.0f",obj.spin_multiplicity);end
            output(end+1)=chargeText+spinText;
            if isa(obj.molecule_, ...
                    "kssolv.analysis.matgenlab.core.Molecule")
                if logical(cartCoords),geometry=obj.get_cart_coords();
                else,geometry=obj.get_zmatrix();end
                output(end+1)=geometry;
            elseif ~isempty(obj.molecule_)
                output(end+1)=string(obj.molecule_);
            end
            output(end+1)="";
            if ~isempty(obj.gen_basis)
                output(end+1)=string(obj.gen_basis)+newline;
            end
            output(end+1)=obj.mapToString(obj.input_parameters,newline);
            output(end+1)=newline;
            value=strjoin(output,newline);
        end

        function value=char(obj),value=char(obj.to_str());end

        function write_file(obj,filename,cartCoords)
            if nargin<3,cartCoords=false;end
            filename=string(filename);
            target=filename;
            compressed=endsWith(lower(filename),".gz");
            if compressed,target=string(tempname);end
            file=fopen(target,"w","n","UTF-8");
            if file<0
                error("KSSOLV:Matgenlab:GaussianInput:Write", ...
                    "Cannot open '%s' for writing.",filename);
            end
            cleanup=onCleanup(@()fclose(file));
            fwrite(file,char(obj.to_str(cartCoords)),"char");
            clear cleanup
            if compressed
                targetCleanup=onCleanup(@()deleteIfPresent(target));
                [directory,~,~]=fileparts(filename);
                if strlength(directory)==0,directory=pwd;end
                generated=gzip(target,directory);
                gzipCleanup=onCleanup(@()deleteIfPresent(generated{1}));
                [success,message]=movefile(generated{1},filename,"f");
                if ~success
                    error("KSSOLV:Matgenlab:GaussianInput:Write", ...
                        "Cannot write compressed Gaussian input: %s", ...
                        message);
                end
                clear gzipCleanup targetCleanup
            end
        end

        function value=as_dict(obj)
            moleculeData=[];
            if isa(obj.molecule_, ...
                    "kssolv.analysis.matgenlab.core.Molecule")
                moleculeData=obj.molecule_.as_dict();
            end
            value=struct();
            value.x_module="pymatgen.io.gaussian";
            value.x_class="GaussianInput";
            value.molecule=moleculeData;
            value.functional=obj.functional;
            value.basis_set=obj.basis_set;
            value.route_parameters=obj.mapToPairs(obj.route_parameters);
            value.title=obj.title;
            value.charge=obj.charge;
            value.spin_multiplicity=obj.spin_multiplicity;
            value.input_parameters=obj.mapToPairs(obj.input_parameters);
            value.link0_parameters=obj.mapToPairs(obj.link0_parameters);
            value.dieze_tag=obj.dieze_tag;
        end

        function value=asDict(obj),value=obj.as_dict();end
    end

    methods (Static)
        function obj=from_str(contents)
            lines=splitlines(string(contents));
            lines=strip(lines);
            link0=containers.Map("KeyType","char","ValueType","any");
            for index=1:numel(lines)
                token=regexp(char(lines(index)), ...
                    '^(%.+?)\s*=\s*(.+)$','tokens','once');
                if ~isempty(token),link0(token{1})=token{2};end
            end
            routeStart=find(startsWith(lower(lines),"#"),1);
            if isempty(routeStart)
                error("KSSOLV:Matgenlab:GaussianInput:Route", ...
                    "Gaussian input does not contain a route card.");
            end
            routeEnd=routeStart;
            while routeEnd<numel(lines)&& ...
                    strlength(strtrim(lines(routeEnd+1)))>0
                routeEnd=routeEnd+1;
            end
            route=strjoin(lines(routeStart:routeEnd)," ");
            [functional,basis,routeParameters,dieze]= ...
                kssolv.analysis.matgenlab.io.read_route_line(route);
            index=routeEnd+1;
            while index<=numel(lines)&&strlength(lines(index))==0
                index=index+1;
            end
            titleLines=strings(0,1);
            while index<=numel(lines)&&strlength(lines(index))>0
                titleLines(end+1)=lines(index); %#ok<AGROW>
                index=index+1;
            end
            title=strjoin(titleLines," ");
            while index<=numel(lines)&&strlength(lines(index))==0
                index=index+1;
            end
            if index>numel(lines)
                error("KSSOLV:Matgenlab:GaussianInput:Charge", ...
                    "Gaussian input is missing charge and multiplicity.");
            end
            chargeSpin=regexp(char(lines(index)), ...
                '^\s*([-+]?\d+(?:\.\d+)?)\s*[,\s]\s*(\d+)', ...
                'tokens','once');
            if isempty(chargeSpin)
                error("KSSOLV:Matgenlab:GaussianInput:Charge", ...
                    "Invalid Gaussian charge/multiplicity line.");
            end
            charge=fix(str2double(chargeSpin{1}));
            spin=fix(str2double(chargeSpin{2}));
            index=index+1;
            while index<=numel(lines)&&strlength(lines(index))==0
                index=index+1;
            end
            geometry=strings(0,1);
            while index<=numel(lines)&&strlength(lines(index))>0
                geometry(end+1)=lines(index); %#ok<AGROW>
                index=index+1;
            end
            variables=strings(0,1);
            next=index+1;
            while next<=numel(lines)&&strlength(lines(next))==0
                next=next+1;
            end
            if ~isempty(geometry)&& ...
                    ~kssolv.analysis.matgenlab.io.GaussianInput. ...
                    isCartesianLine(geometry(1))
                while next<=numel(lines)&&strlength(lines(next))>0
                    variables(end+1)=lines(next); %#ok<AGROW>
                    next=next+1;
                end
                index=next;
            end
            molecule=kssolv.analysis.matgenlab.io.GaussianInput. ...
                parseCoords([geometry(:);variables(:)]);
            molecule=molecule.set_charge_and_spin(charge,spin);
            inputParameters=containers.Map( ...
                "KeyType","char","ValueType","any");
            for lineIndex=index+1:numel(lines)
                pair=regexp(char(lines(lineIndex)), ...
                    '^\s*([^=]+?)\s*=\s*(.+)$','tokens','once');
                if ~isempty(pair)
                    inputParameters(strtrim(pair{1}))=strtrim(pair{2});
                end
            end
            obj=kssolv.analysis.matgenlab.io.GaussianInput( ...
                molecule,charge,spin,title,functional,basis, ...
                routeParameters,inputParameters,link0,dieze);
        end

        function obj=from_file(filename)
            obj=kssolv.analysis.matgenlab.io.GaussianInput. ...
                from_str(readText(filename));
        end

        function obj=from_dict(value)
            molecule=[];
            if isfield(value,"molecule")&&~isempty(value.molecule)
                molecule=kssolv.analysis.matgenlab.core.Molecule. ...
                    from_dict(value.molecule);
            end
            obj=kssolv.analysis.matgenlab.io.GaussianInput( ...
                molecule,value.charge,value.spin_multiplicity, ...
                value.title,value.functional,value.basis_set, ...
                kssolv.analysis.matgenlab.io.GaussianInput. ...
                pairsToMap(value.route_parameters), ...
                kssolv.analysis.matgenlab.io.GaussianInput. ...
                pairsToMap(value.input_parameters), ...
                kssolv.analysis.matgenlab.io.GaussianInput. ...
                pairsToMap(value.link0_parameters), ...
                value.dieze_tag);
        end

        function obj=fromDict(value)
            obj=kssolv.analysis.matgenlab.io.GaussianInput. ...
                from_dict(value);
        end
    end

    methods (Static,Access=private)
        function molecule=parseCoords(lines)
            lines=reshape(string(lines),[],1);
            variables=containers.Map( ...
                "KeyType","char","ValueType","double");
            for line=lines.'
                match=regexp(char(strtrim(line)), ...
                    '^([A-Za-z]+\S*)[\s=,]+([-+]?\d*\.?\d+)$', ...
                    'tokens','once');
                if ~isempty(match)
                    variables(strrep(match{1},"=",""))= ...
                        str2double(match{2});
                end
            end
            species=cell(1,0);coordinates=zeros(0,3);zmode=false;
            for line=lines.'
                text=strtrim(line);
                if strlength(text)==0||lower(text)=="variables:",continue,end
                if ~zmode&&kssolv.analysis.matgenlab.io. ...
                        GaussianInput.isCartesianLine(text)
                    tokens=regexp(char(text),'[,\s]+','split');
                    species{end+1}=kssolv.analysis.matgenlab.io. ...
                        GaussianInput.parseSpecies(tokens{1}); ...
                        %#ok<AGROW>
                    values=str2double(tokens(2:end));
                    if numel(values)>3,values=values(2:4);
                    else,values=values(1:3);end
                    coordinates(end+1,:)=values; %#ok<AGROW>
                    continue
                end
                tokens=regexp(char(text),'[,\s]+','split');
                if mod(numel(tokens)-1,2)~=0||numel(tokens)>7
                    continue
                end
                zmode=true;
                species{end+1}=kssolv.analysis.matgenlab.io. ...
                    GaussianInput.parseSpecies(tokens{1}); ...
                    %#ok<AGROW>
                tokens=tokens(2:end);
                if isempty(tokens)
                    coordinates(end+1,:)=[0,0,0]; %#ok<AGROW>
                    continue
                end
                references=zeros(1,numel(tokens)/2);
                parameters=zeros(size(references));
                for pair=1:numel(references)
                    reference=tokens{2*pair-1};
                    numeric=str2double(reference);
                    if isnan(numeric)
                        labels=regexprep(string(species),'\\d','');
                        referenceSymbol=regexprep(string(reference),'\\d','');
                        references(pair)=find( ...
                            labels==referenceSymbol,1);
                    else
                        references(pair)=fix(numeric);
                    end
                    value=tokens{2*pair};
                    numeric=str2double(value);
                    if isnan(numeric)
                        signValue=1;
                        if startsWith(value,"-")
                            signValue=-1;value=value(2:end);
                        end
                        if ~isKey(variables,value)
                            error( ...
                                "KSSOLV:Matgenlab:GaussianInput:Variable", ...
                                "Undefined Z-matrix variable '%s'.",value);
                        end
                        numeric=signValue*variables(value);
                    end
                    parameters(pair)=numeric;
                end
                coordinates(end+1,:)=kssolv.analysis.matgenlab.io. ...
                    GaussianInput.zCoordinate( ...
                    coordinates,references,parameters); %#ok<AGROW>
            end
            if isempty(species)
                error("KSSOLV:Matgenlab:GaussianInput:Geometry", ...
                    "Gaussian input does not contain a molecular geometry.");
            end
            molecule=kssolv.analysis.matgenlab.core.Molecule( ...
                species,coordinates);
        end

        function coordinate=zCoordinate(coords,references,parameters)
            if isscalar(references)
                coordinate=[0,0,parameters(1)];
            elseif numel(references)==2
                first=coords(references(1),:);
                second=coords(references(2),:);
                operation=kssolv.analysis.matgenlab.core.SymmOp. ...
                    from_origin_axis_angle(first,[0,1,0],parameters(2));
                coordinate=operation.operate(second);
                vector=coordinate-first;
                coordinate=first+vector*parameters(1)/norm(vector);
            else
                first=coords(references(1),:);
                second=coords(references(2),:);
                third=coords(references(3),:);
                axis=cross(third-second,first-second);
                operation=kssolv.analysis.matgenlab.core.SymmOp. ...
                    from_origin_axis_angle(first,axis,parameters(2));
                coordinate=operation.operate(second);
                vectorOne=coordinate-first;
                vectorTwo=first-second;
                vectorThree=cross(vectorOne,vectorTwo);
                cosine=dot(vectorThree,axis)/ ...
                    (norm(vectorThree)*norm(axis));
                adjustment=acosd(max(-1,min(1,cosine)));
                axis=first-second;
                operation=kssolv.analysis.matgenlab.core.SymmOp. ...
                    from_origin_axis_angle(first,axis, ...
                    parameters(3)-adjustment);
                coordinate=operation.operate(coordinate);
                vector=coordinate-first;
                coordinate=first+vector*parameters(1)/norm(vector);
            end
        end

        function tf=isCartesianLine(line)
            tf=~isempty(regexp(char(strtrim(line)), ...
                '^\w+[\s,]+[-+\d\.eE]+[\s,]+[-+\d\.eE]+[\s,]+[-+\d\.eE]+', ...
                'once'));
        end

        function value=parseSpecies(text)
            number=str2double(text);
            if ~isnan(number),value=fix(number);return,end
            value=char(regexprep(string(text),'\d',''));
            value=string([upper(value(1)),lower(value(2:end))]);
        end

        function value=optionalString(input)
            if isempty(input),value=missing;else,value=string(input);end
        end

        function map=normalizeMap(value)
            map=containers.Map("KeyType","char","ValueType","any");
            if isempty(value),return,end
            if isa(value,"containers.Map")
                names=keys(value);
                for index=1:numel(names)
                    item=value(names{index});
                    if isa(item,"containers.Map")||isstruct(item)
                        item=kssolv.analysis.matgenlab.io.GaussianInput. ...
                            normalizeMap(item);
                    end
                    map(names{index})=item;
                end
            elseif isstruct(value)
                names=fieldnames(value);
                for index=1:numel(names)
                    item=value.(names{index});
                    if isa(item,"containers.Map")||isstruct(item)
                        item=kssolv.analysis.matgenlab.io.GaussianInput. ...
                            normalizeMap(item);
                    end
                    map(names{index})=item;
                end
            elseif iscell(value)&&size(value,2)==2
                for index=1:size(value,1)
                    map(char(string(value{index,1})))=value{index,2};
                end
            else
                error("KSSOLV:Matgenlab:GaussianInput:Parameters", ...
                    "Gaussian parameters must be a map, struct, or N-by-2 cell.");
            end
        end

        function text=mapToString(map,joiner)
            names=sort(string(keys(map)));
            entries=strings(1,numel(names));
            for index=1:numel(names)
                value=map(char(names(index)));
                if isempty(value)||(isstring(value)&&strlength(value)==0)
                    entries(index)=names(index);
                elseif isa(value,"containers.Map")
                    entries(index)=names(index)+"=(" + ...
                        kssolv.analysis.matgenlab.io.GaussianInput. ...
                        mapToString(value,",")+")";
                else
                    entries(index)=names(index)+"="+string(value);
                end
            end
            text=strjoin(entries,joiner);
        end

        function pairs=mapToPairs(map)
            names=sort(string(keys(map)));
            pairs=cell(numel(names),2);
            for index=1:numel(names)
                pairs{index,1}=char(names(index));
                value=map(char(names(index)));
                if isa(value,"containers.Map")
                    value=kssolv.analysis.matgenlab.io.GaussianInput. ...
                        mapToPairs(value);
                end
                pairs{index,2}=value;
            end
        end

        function map=pairsToMap(value)
            map=kssolv.analysis.matgenlab.io.GaussianInput. ...
                normalizeMap(value);
        end
    end
end

function text=readText(filename)
filename=char(string(filename));
if endsWith(lower(filename),".gz")
    directory=tempname;mkdir(directory);
    cleanup=onCleanup(@()rmdir(directory,"s"));
    files=gunzip(filename,directory);
    text=string(fileread(files{1}));
else
    text=string(fileread(filename));
end
end

function deleteIfPresent(filename)
if isfile(filename),delete(filename);end
end
