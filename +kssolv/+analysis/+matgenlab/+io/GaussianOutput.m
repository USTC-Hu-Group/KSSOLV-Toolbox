classdef GaussianOutput
    %GAUSSIANOUTPUT Parse Gaussian log/output files without Python.
    %
    % Native MATLAB implementation of pymatgen-core v2026.7.24.

    properties
        filename string
        properly_terminated (1,1) logical=false
        is_pcm (1,1) logical=false
        is_spin (1,1) logical=false
        pcm
        hessian
        title
        stationary_type string="Minimum"
        corrections
        energies double=zeros(1,0)
        errors string=strings(1,0)
        Mulliken_charges
        link0
        cart_forces cell=cell(1,0)
        frequencies cell=cell(1,0)
        eigenvalues
        eigenvectors
        molecular_orbital
        atom_basis_labels cell=cell(1,0)
        resumes cell=cell(1,0)
        bond_orders double=zeros(0)
        structures_input_orientation cell=cell(1,0)
        structures cell=cell(1,0)
        opt_structures cell=cell(1,0)
        standard_orientation (1,1) logical=false
        functional
        basis_set
        route_parameters
        dieze_tag
        charge
        spin_multiplicity
        num_basis_func
        electrons
    end

    properties (Access=private)
        text_ string
    end

    properties (Dependent,SetAccess=private)
        final_energy
        final_structure
    end

    methods
        function obj=GaussianOutput(filename)
            if nargin<1||strlength(string(filename))==0
                error("KSSOLV:Matgenlab:GaussianOutput:Filename", ...
                    "A Gaussian output filename is required.");
            end
            obj.filename=string(filename);
            if ~isfile(obj.filename)
                error("KSSOLV:Matgenlab:GaussianOutput:MissingFile", ...
                    "Gaussian output file '%s' does not exist.",obj.filename);
            end
            obj.text_=readOutputText(obj.filename);
            obj=obj.parse();
        end

        function value=get.final_energy(obj)
            if isempty(obj.energies)
                error("KSSOLV:Matgenlab:GaussianOutput:NoEnergy", ...
                    "Gaussian output contains no electronic energies.");
            end
            value=obj.energies(end);
        end

        function value=get.final_structure(obj)
            if isempty(obj.structures)
                error("KSSOLV:Matgenlab:GaussianOutput:NoStructure", ...
                    "Gaussian output contains no molecular structures.");
            end
            value=obj.structures{end};
        end

        function value=as_dict(obj)
            molecule=obj.final_structure;
            composition=molecule.composition.as_dict();
            output=struct();
            output.energies=obj.energies;
            output.final_energy=obj.final_energy;
            output.final_energy_per_atom= ...
                obj.final_energy/molecule.num_sites;
            output.molecule=molecule.as_dict();
            output.stationary_type=obj.stationary_type;
            output.corrections=obj.corrections;
            input=struct();
            input.route=obj.mapPairs(obj.route_parameters);
            input.functional=obj.functional;
            input.basis_set=obj.basis_set;
            input.nbasisfunctions=obj.num_basis_func;
            input.pcm_parameters=obj.pcm;
            symbols=sort(molecule.symbol_set);
            reducedComposition=molecule.composition.reduced_composition;
            value=struct();
            value.has_gaussian_completed=obj.properly_terminated;
            value.nsites=molecule.num_sites;
            value.unit_cell_formula=composition;
            value.reduced_cell_formula=reducedComposition.as_dict();
            value.pretty_formula=molecule.reduced_formula;
            value.is_pcm=obj.is_pcm;
            value.errors=obj.errors;
            value.Mulliken_charges=obj.Mulliken_charges;
            value.elements=symbols;
            value.nelements=numel(symbols);
            value.charge=obj.charge;
            value.spin_multiplicity=obj.spin_multiplicity;
            value.input=input;
            value.output=output;
            value.x_module="pymatgen.io.gaussian";
            value.x_class="GaussianOutput";
        end

        function value=asDict(obj),value=obj.as_dict();end

        function data=read_scan(obj)
            lines=splitlines(obj.text_);
            data=struct("energies",zeros(1,0),"coords", ...
                containers.Map("KeyType","char","ValueType","any"));
            for lineIndex=1:numel(lines)
                if contains(lines(lineIndex), ...
                        "Summary of Optimized Potential Surface Scan")
                    index=lineIndex+2;
                    while index<=numel(lines)
                        energyValues=floatNumbers(lines(index));
                        if isempty(energyValues),break,end
                        data.energies=[data.energies,energyValues];
                        index=index+1;
                        while index<=numel(lines)
                            match=regexp(char(lines(index)), ...
                                '^\s*(\w+)((?:\s*[+-]?\d+\.\d+)+)', ...
                                'tokens','once');
                            if isempty(match),break,end
                            name=match{1};
                            coordinateValues=floatNumbers(match{2});
                            if isKey(data.coords,name)
                                data.coords(name)=[data.coords(name), ...
                                    coordinateValues];
                            else
                                data.coords(name)=coordinateValues;
                            end
                            index=index+1;
                        end
                        if index>numel(lines)||isempty(regexp( ...
                                char(lines(index)), ...
                                '^\s+(?:\s*\d+)+','once'))
                            break
                        end
                        index=index+1;
                    end
                    return
                end
                if contains(lines(lineIndex), ...
                        "Summary of the potential surface scan:")
                    if lineIndex+1>numel(lines),return,end
                    header=split(strtrim(lines(lineIndex+1)));
                    for coordinateIndex=2:numel(header)-1
                        data.coords(char(header(coordinateIndex)))= ...
                            zeros(1,0);
                    end
                    index=lineIndex+3;
                    while index<=numel(lines)&&isempty(regexp( ...
                            char(lines(index)),'^\s*-+','once'))
                        values=str2double(split(strtrim(lines(index))));
                        values=reshape(values,1,[]);
                        if all(isfinite(values))&&numel(values)>=2
                            data.energies(end+1)=values(end);
                            names=keys(data.coords);
                            for coordinateIndex=1:numel(names)
                                current=data.coords(names{coordinateIndex});
                                current(end+1)=values(coordinateIndex+1); ...
                                    %#ok<AGROW>
                                data.coords(names{coordinateIndex})=current;
                            end
                        end
                        index=index+1;
                    end
                    return
                end
            end
        end

        function axesHandle=get_scan_plot(obj,coords)
            if nargin<2,coords="";end
            data=obj.read_scan();
            if isempty(data.energies)
                error("KSSOLV:Matgenlab:GaussianOutput:NoScan", ...
                    "Gaussian output contains no potential-energy scan.");
            end
            figureHandle=figure("Visible","off","Color","white");
            axesHandle=axes(figureHandle);
            name=char(string(coords));
            if strlength(string(coords))>0&&isKey(data.coords,name)
                x=data.coords(name);xLabel=string(coords);
            else
                x=0:numel(data.energies)-1;xLabel="points";
            end
            y=(data.energies-min(data.energies))* ...
                kssolv.analysis.matgenlab.core.Ha_to_eV();
            plot(axesHandle,x,y,"ro--");
            xlabel(axesHandle,xLabel);ylabel(axesHandle,"Energy (eV)");
            axesHandle.UserData=struct("x",x,"y",y,"coordinate",xLabel);
        end

        function save_scan_plot(obj,filename,imgFormat,coords)
            if nargin<2,filename="scan.pdf";end
            if nargin<3,imgFormat="pdf";end
            if nargin<4,coords="";end
            axesHandle=obj.get_scan_plot(coords);
            cleanup=onCleanup(@()delete(ancestor(axesHandle,"figure")));
            filename=obj.ensureExtension(filename,imgFormat);
            exportgraphics(axesHandle,filename);
        end

        function transitions=read_excitation_energies(obj)
            lines=splitlines(obj.text_);
            active=false;transitions=zeros(0,3);
            for index=1:numel(lines)
                if contains(lines(index), ...
                        "Excitation energies and oscillator strengths:")
                    active=true;continue
                end
                if active&&~isempty(regexp(char(lines(index)), ...
                        '^\s*Excited State\s*\d','once'))
                    values=numbers(lines(index));
                    if numel(values)>=4
                        transitions(end+1,:)=values(2:4); %#ok<AGROW>
                    end
                end
            end
        end

        function [data,axesHandle]=get_spectre_plot(obj,sigma,step)
            if nargin<2,sigma=.05;end
            if nargin<3,step=.01;end
            if ~isscalar(sigma)||sigma<=0||~isfinite(sigma)|| ...
                    ~isscalar(step)||step<=0||~isfinite(step)
                error("KSSOLV:Matgenlab:GaussianOutput:SpectrumGrid", ...
                    "sigma and step must be positive finite scalars.");
            end
            transitions=obj.read_excitation_energies();
            if isempty(transitions)
                error("KSSOLV:Matgenlab:GaussianOutput:NoExcitations", ...
                    "Gaussian output contains no excitation energies.");
            end
            minimum=min(transitions(:,1))-5*sigma;
            maximum=max(transitions(:,1))+5*sigma;
            count=fix((maximum-minimum)/step)+1;
            energyGrid=linspace(minimum,maximum,count);
            wavelengths=1239.8419843320026./energyGrid;
            spectrum=zeros(size(energyGrid));
            for index=1:size(transitions,1)
                spectrum=spectrum+transitions(index,3)* ...
                    exp(-.5*((energyGrid-transitions(index,1))/ ...
                    sigma).^2)/(sigma*sqrt(2*pi));
            end
            spectrum=spectrum/max(spectrum);
            data=struct("energies",energyGrid,"lambda",wavelengths, ...
                "xas",spectrum);
            figureHandle=figure("Visible","off","Color","white");
            axesHandle=axes(figureHandle);hold(axesHandle,"on");
            plot(axesHandle,wavelengths,spectrum,"r-", ...
                "DisplayName","spectre");
            for index=1:size(transitions,1)
                line(axesHandle,[transitions(index,2), ...
                    transitions(index,2)],[0,transitions(index,3)], ...
                    "Color","blue","LineWidth",2);
            end
            xlabel(axesHandle,"\lambda (nm)");
            ylabel(axesHandle,"Arbitrary unit");
            axesHandle.UserData=struct("transitions",transitions, ...
                "spectrum",data);
        end

        function save_spectre_plot(obj,filename,imgFormat,sigma,step)
            if nargin<2,filename="spectre.pdf";end
            if nargin<3,imgFormat="pdf";end
            if nargin<4,sigma=.05;end
            if nargin<5,step=.01;end
            [~,axesHandle]=obj.get_spectre_plot(sigma,step);
            cleanup=onCleanup(@()delete(ancestor(axesHandle,"figure")));
            filename=obj.ensureExtension(filename,imgFormat);
            exportgraphics(axesHandle,filename);
        end

        function input=to_input(obj,mol,charge,spinMultiplicity,title, ...
                functional,basisSet,routeParameters,inputParameters, ...
                link0Parameters,diezeTag,cartCoords) %#ok<INUSD>
            if nargin<2||isempty(mol),mol=obj.final_structure;end
            if nargin<3||isempty(charge),charge=obj.charge;end
            if nargin<4||isempty(spinMultiplicity)
                spinMultiplicity=obj.spin_multiplicity;
            end
            if nargin<5||strlength(string(title))==0,title=obj.title;end
            if nargin<6||strlength(string(functional))==0
                functional=obj.functional;
            end
            if nargin<7||strlength(string(basisSet))==0
                basisSet=obj.basis_set;
            end
            if nargin<8||isempty(routeParameters)
                routeParameters=obj.route_parameters;
            end
            if nargin<9,inputParameters=[];end
            if nargin<10||isempty(link0Parameters)
                link0Parameters=obj.link0;
            end
            if nargin<11||strlength(string(diezeTag))==0
                diezeTag=obj.dieze_tag;
            end
            input=kssolv.analysis.matgenlab.io.GaussianInput( ...
                mol,charge,spinMultiplicity,title,functional,basisSet, ...
                routeParameters,inputParameters,link0Parameters,diezeTag);
        end
    end

    methods (Access=private)
        function obj=parse(obj)
            lines=splitlines(obj.text_);
            obj.pcm=containers.Map("KeyType","char","ValueType","any");
            obj.corrections=containers.Map( ...
                "KeyType","char","ValueType","double");
            obj.link0=containers.Map("KeyType","char","ValueType","any");
            obj.Mulliken_charges=containers.Map( ...
                "KeyType","double","ValueType","any");
            obj.route_parameters=containers.Map( ...
                "KeyType","char","ValueType","any");
            obj.eigenvalues=struct("up",zeros(1,0),"down",zeros(1,0));
            obj.eigenvectors=struct("up",zeros(0),"down",zeros(0));
            obj.molecular_orbital=struct();
            obj.functional="";obj.basis_set="";obj.dieze_tag="";
            obj.charge=[];obj.spin_multiplicity=[];obj.num_basis_func=[];
            obj.electrons=[];obj.hessian=[];obj.title="";
            for index=1:numel(lines)
                line=char(lines(index));
                link=regexp(line,'^\s*(%.+?)\s*=\s*(.+)$', ...
                    'tokens','once');
                if ~isempty(link),obj.link0(link{1})=link{2};end
            end
            [obj.functional,obj.basis_set,obj.route_parameters, ...
                obj.dieze_tag,routeEnd]=obj.parseRoute(lines);
            obj.title=obj.parseTitle(lines,routeEnd);
            obj=obj.parseScalarProperties(lines);
            [obj.eigenvectors,obj.molecular_orbital, ...
                obj.atom_basis_labels]=obj.parseMolecularOrbitals(lines);
            [inputStructures,standardStructures,optimizations, ...
                standard]=obj.parseStructures(lines);
            obj.structures_input_orientation=inputStructures;
            obj.standard_orientation=standard;
            if standard,obj.structures=standardStructures;
            else,obj.structures=inputStructures;end
            obj.opt_structures=optimizations;
            obj.frequencies=obj.parseFrequencies(lines);
            obj.hessian=obj.parseHessian(lines);
            obj.bond_orders=obj.parseBondOrders(lines,inputStructures);
            obj.resumes=obj.parseResumes(lines);
            obj.Mulliken_charges=obj.parseMulliken(lines);
            if ~obj.properly_terminated
                warning("KSSOLV:Matgenlab:GaussianOutput:Termination", ...
                    "%s: Termination error or bad Gaussian output file.", ...
                    obj.filename);
            end
        end

        function [functional,basis,route,dieze,routeEnd]= ...
                parseRoute(~,lines)
            functional="";basis="";dieze="";
            route=containers.Map("KeyType","char","ValueType","any");
            routeStart=find(~cellfun(@isempty,regexp(cellstr(lines), ...
                '^\s*#[pPnNtT]*\s','once')),1);
            routeEnd=[];
            if isempty(routeStart),return,end
            routeLines=strings(0,1);
            index=routeStart;
            while index<=numel(lines)
                if index>routeStart&& ...
                        ~isempty(regexp(char(strtrim(lines(index))), ...
                        '^-+$','once'))
                    routeEnd=index;break
                end
                routeLines(end+1)=strtrim(lines(index)); %#ok<AGROW>
                index=index+1;
            end
            [functional,basis,route,dieze]= ...
                kssolv.analysis.matgenlab.io.read_route_line( ...
                strjoin(routeLines," "));
        end

        function title=parseTitle(~,lines,routeEnd)
            title="";
            if isempty(routeEnd),return,end
            index=routeEnd+1;
            while index<=numel(lines)
                if ~isempty(regexp(char(strtrim(lines(index))), ...
                        '^-+$','once'))
                    candidate=index+1;
                    while candidate<=numel(lines)&& ...
                            strlength(strtrim(lines(candidate)))==0
                        candidate=candidate+1;
                    end
                    if candidate<=numel(lines)&& ...
                            isempty(regexp(char(strtrim(lines(candidate))), ...
                            '^-+$','once'))
                        title=strtrim(lines(candidate));return
                    end
                end
                index=index+1;
            end
        end

        function obj=parseScalarProperties(obj,lines)
            forceActive=false;forces=zeros(1,0);
            eigenActive=false;eigenLines=strings(0,1);
            pcmActive=false;
            for index=1:numel(lines)
                line=char(lines(index));
                match=regexp(line, ...
                    'Charge\s+=\s*([-\d]+)\s+Multiplicity\s+=\s*(\d+)', ...
                    'tokens','once');
                if ~isempty(match)
                    obj.charge=str2double(match{1});
                    obj.spin_multiplicity=str2double(match{2});
                end
                match=regexp(line,'(\d+)\s+basis functions', ...
                    'tokens','once');
                if ~isempty(match),obj.num_basis_func=str2double(match{1});end
                match=regexp(line, ...
                    '(\d+)\s+alpha electrons\s+(\d+)\s+beta electrons', ...
                    'tokens','once');
                if ~isempty(match)
                    obj.electrons=[str2double(match{1}), ...
                        str2double(match{2})];
                end
                match=regexp(line,'E\(.*\)\s*=\s*([-\.\d]+)\s+', ...
                    'tokens','once');
                if ~isempty(match)
                    obj.energies(end+1)=str2double(match{1});
                end
                match=regexp(line,'EUMP2\s*=\s*(\S+)', ...
                    'tokens','once');
                if ~isempty(match)
                    obj.energies(end+1)=str2double( ...
                        strrep(match{1},"D","E"));
                end
                match=regexp(line, ...
                    'ONIOM:\s+extrapolated energy\s*=\s*(\S+)', ...
                    'tokens','once');
                if ~isempty(match)
                    obj.energies(end+1)=str2double(match{1});
                end
                if contains(line,"Normal termination")
                    obj.properly_terminated=true;
                end
                if contains(line,"! Non-Optimized Parameters !")
                    obj.errors(end+1)="Optimization error";
                elseif contains(line,"Convergence failure")
                    obj.errors(end+1)="SCF convergence error";
                end
                if contains(line,"imaginary frequencies")&& ...
                        obj.mapHas(obj.route_parameters,"freq")&& ...
                        obj.mapHas(obj.route_parameters,"opt")
                    obj.stationary_type="Saddle";
                end
                correction=regexp(line, ...
                    '(Zero-point|Thermal) correction(.*)=\s+([\d\.-]+)', ...
                    'tokens','once');
                if ~isempty(correction)
                    if correction{1}=="Zero-point"
                        key="Zero-point";
                    else
                        key=strtrim(strrep(correction{2}," to ",""));
                    end
                    obj.corrections(char(key))=str2double(correction{3});
                end
                if contains(line,"Polarizable Continuum Model")
                    obj.is_pcm=true;pcmActive=true;
                end
                if pcmActive,obj=obj.parsePcmLine(line);end
                if contains(line,"Center")&&contains(line,"Atomic")&& ...
                        contains(line,"Forces")&&contains(line,"Hartrees/Bohr")
                    forceActive=true;forces=zeros(1,0);continue
                end
                if forceActive
                    force=regexp(line, ...
                        '^\s+\d+\s+\d+\s+([-\d\.]+)\s+([-\d\.]+)\s+([-\d\.]+)', ...
                        'tokens','once');
                    if ~isempty(force)
                        forces=[forces,str2double(force)]; %#ok<AGROW>
                    elseif contains(line,"Cartesian Forces:")
                        obj.cart_forces{end+1}=forces;
                        forceActive=false;
                    end
                end
                if ~isempty(regexp(line, ...
                        '(Alpha|Beta)\s*\S+\s*eigenvalues --','once'))
                    eigenActive=true;eigenLines(end+1)=string(line); ...
                        %#ok<AGROW>
                elseif eigenActive
                    obj=obj.consumeEigenLines(eigenLines);
                    eigenLines=strings(0,1);eigenActive=false;
                end
            end
            if eigenActive,obj=obj.consumeEigenLines(eigenLines);end
            obj.is_spin=~isempty(obj.eigenvalues.down);
        end

        function obj=consumeEigenLines(obj,lines)
            up=zeros(1,0);down=zeros(1,0);
            for lineIndex=1:numel(lines)
                line=lines(lineIndex);
                values=numbers(extractAfter(line,"--"));
                if contains(line,"Beta")
                    down=[down,values]; %#ok<AGROW>
                else
                    up=[up,values]; %#ok<AGROW>
                end
            end
            obj.eigenvalues=struct("up",up,"down",down);
        end

        function [vectors,orbitals,labels]= ...
                parseMolecularOrbitals(obj,lines)
            vectors=struct("up",zeros(0),"down",zeros(0));
            orbitals=struct("up",{{}},"down",{{}});
            labels=cell(1,0);
            if isempty(obj.num_basis_func),return,end
            spinNames=["up","down"];
            headings=["Alpha Molecular Orbital Coefficients:", ...
                "Beta Molecular Orbital Coefficients:"];
            for spinIndex=1:2
                candidates=find(contains(lines,headings(spinIndex)));
                if isempty(candidates),continue,end
                start=candidates(end)+1;
                matrix=zeros(obj.num_basis_func);
                atomForRow=zeros(1,obj.num_basis_func);
                labelForRow=strings(1,obj.num_basis_func);
                columns=zeros(1,0);index=start;
                while index<=numel(lines)
                    text=char(lines(index));
                    if index>start&&(contains(text, ...
                            "Molecular Orbital Coefficients:")|| ...
                            contains(text,"Density Matrix:"))
                        break
                    end
                    header=regexp(text, ...
                        '^\s*(\d+(?:\s+\d+)*)\s*$','tokens','once');
                    if ~isempty(header)
                        columns=str2double(split(strtrim(header{1}))).';
                        index=index+1;continue
                    end
                    tokens=split(strtrim(string(text)));
                    coefficientCount=numel(columns);
                    prefixCount=numel(tokens)-coefficientCount;
                    if ~isempty(columns)&&prefixCount>=2&& ...
                            all(isfinite(str2double( ...
                            tokens(prefixCount+1:end))))
                        rowIndex=str2double(tokens(1));
                        if rowIndex>=1&&rowIndex<=obj.num_basis_func
                            if prefixCount>=4&& ...
                                    isfinite(str2double(tokens(2)))
                                atomForRow(rowIndex)= ...
                                    str2double(tokens(2));
                                orbitalLabel=tokens(4);
                            elseif rowIndex>1
                                atomForRow(rowIndex)=atomForRow(rowIndex-1);
                                orbitalLabel=tokens(prefixCount);
                            else
                                orbitalLabel=tokens(prefixCount);
                            end
                            labelForRow(rowIndex)=orbitalLabel;
                            coefficients=str2double( ...
                                tokens(prefixCount+1:end)).';
                            count=min(numel(columns),numel(coefficients));
                            matrix(rowIndex,columns(1:count))= ...
                                coefficients(1:count);
                        end
                    end
                    index=index+1;
                end
                field=char(spinNames(spinIndex));
                vectors.(field)=matrix;
                if isempty(labels)&&any(atomForRow)
                    labels=cell(1,max(atomForRow));
                    for rowIndex=1:numel(atomForRow)
                        atomIndex=atomForRow(rowIndex);
                        if atomIndex>0
                            labels{atomIndex}{end+1}= ...
                                char(labelForRow(rowIndex));
                        end
                    end
                end
                orbitalList=cell(1,obj.num_basis_func);
                for orbitalIndex=1:obj.num_basis_func
                    atoms=cell(1,numel(labels));
                    rowIndex=1;
                    for atomIndex=1:numel(labels)
                        coefficients=containers.Map( ...
                            "KeyType","char","ValueType","double");
                        for labelIndex=1:numel(labels{atomIndex})
                            coefficients(labels{atomIndex}{labelIndex})= ...
                                matrix(rowIndex,orbitalIndex);
                            rowIndex=rowIndex+1;
                        end
                        atoms{atomIndex}=coefficients;
                    end
                    orbitalList{orbitalIndex}=atoms;
                end
                orbitals.(field)=orbitalList;
            end
        end

        function obj=parsePcmLine(obj,line)
            patterns={ ...
                '(Dispersion|Cavitation|Repulsion) energy\s+\S+\s+=\s+(\S*)'
                'with all non electrostatic terms\s+\S+\s+=\s+(\S*)'
                '(Eps|Numeral density|RSolv|Eps\(inf[inity]*\))\s+=\s*(\S*)'};
            match=regexp(line,patterns{1},'tokens','once');
            if ~isempty(match)
                obj.pcm([match{1},' energy'])=str2double(match{2});return
            end
            match=regexp(line,patterns{2},'tokens','once');
            if ~isempty(match)
                obj.pcm("Total energy")=str2double(match{1});return
            end
            match=regexp(line,patterns{3},'tokens','once');
            if ~isempty(match),obj.pcm(match{1})=str2double(match{2});end
        end

        function [input,standard,optimized,hasStandard]= ...
                parseStructures(~,lines)
            input=cell(1,0);standard=cell(1,0);optimized=cell(1,0);
            hasStandard=false;lastInput=[];lastStandard=[];
            index=1;
            while index<=numel(lines)
                line=lines(index);
                if contains(line,"Standard orientation")
                    [molecule,index]=orientationBlock(lines,index);
                    standard{end+1}=molecule; %#ok<AGROW>
                    lastStandard=molecule;hasStandard=true;continue
                elseif contains(line,"Input orientation")|| ...
                        contains(line,"Z-Matrix orientation")
                    [molecule,index]=orientationBlock(lines,index);
                    input{end+1}=molecule; %#ok<AGROW>
                    lastInput=molecule;continue
                elseif contains(line,"Optimization completed.")
                    if hasStandard&&~isempty(lastStandard)
                        optimized{end+1}=lastStandard; %#ok<AGROW>
                    elseif ~isempty(lastInput)
                        optimized{end+1}=lastInput; %#ok<AGROW>
                    end
                end
                index=index+1;
            end
        end

        function groups=parseFrequencies(~,lines)
            headers=find(contains(lines, ...
                "Harmonic frequencies (cm**-1)"));
            groups=cell(1,numel(headers));
            for headerIndex=1:numel(headers)
                stop=numel(lines);
                if headerIndex<numel(headers),stop=headers(headerIndex+1)-1;end
                modes=struct("frequency",{},"r_mass",{}, ...
                    "f_constant",{},"IR_intensity",{}, ...
                    "symmetry",{},"mode",{});
                index=headers(headerIndex)+1;
                while index<=stop
                    if contains(lines(index),"Frequencies --")
                        frequencyValues=numbers( ...
                            extractAfter(lines(index),"--"));
                        count=numel(frequencyValues);
                        symmetries=split(strtrim(lines(max(1,index-1))));
                        masses=zeros(1,count);constants=zeros(1,count);
                        intensities=zeros(1,count);tableIndex=[];
                        cursor=index+1;
                        while cursor<=stop&&cursor<=index+12
                            if contains(lines(cursor),"Red. masses --")
                                masses=numbers(extractAfter( ...
                                    lines(cursor),"--"));
                            elseif contains(lines(cursor),"Frc consts  --")
                                constants=numbers(extractAfter( ...
                                    lines(cursor),"--"));
                            elseif contains(lines(cursor),"IR Inten    --")
                                intensities=numbers(extractAfter( ...
                                    lines(cursor),"--"));
                            elseif contains(lines(cursor),"Atom  AN")
                                tableIndex=cursor+1;break
                            end
                            cursor=cursor+1;
                        end
                        vectors=cell(1,count);
                        for modeIndex=1:count,vectors{modeIndex}=zeros(1,0);end
                        if ~isempty(tableIndex)
                            cursor=tableIndex;
                            while cursor<=stop
                                values=numbers(lines(cursor));
                                if numel(values)<2+3*count,break,end
                                components=values(3:end);
                                for modeIndex=1:count
                                    range=(modeIndex-1)*3+(1:3);
                                    vectors{modeIndex}=[ ...
                                        vectors{modeIndex}, ...
                                        components(range)];
                                end
                                cursor=cursor+1;
                            end
                        end
                        for modeIndex=1:count
                            symmetry="";
                            if numel(symmetries)>=modeIndex
                                symmetry=symmetries(modeIndex);
                            end
                            modes(end+1)=struct( ...
                                "frequency",frequencyValues(modeIndex), ...
                                "r_mass",itemAt(masses,modeIndex), ...
                                "f_constant",itemAt(constants,modeIndex), ...
                                "IR_intensity", ...
                                itemAt(intensities,modeIndex), ...
                                "symmetry",symmetry, ...
                                "mode",vectors{modeIndex}); %#ok<AGROW>
                        end
                    end
                    index=index+1;
                end
                groups{headerIndex}=modes;
            end
        end

        function hessian=parseHessian(obj,lines)
            hessian=[];
            header=find(contains(lines, ...
                "Force constants in Cartesian coordinates:"),1);
            if isempty(header)||isempty(obj.structures),return,end
            dimension=3*obj.structures{1}.num_sites;
            hessian=zeros(dimension);
            columns=zeros(1,0);index=header+1;
            while index<=numel(lines)
                text=strtrim(lines(index));
                if strlength(text)==0,index=index+1;continue,end
                tokens=split(text);
                values=str2double(tokens);
                if all(~isnan(values))&&all(values==fix(values))&& ...
                        all(values>=1)&&numel(values)<=5
                    columns=reshape(values,1,[]);index=index+1;continue
                end
                match=regexp(char(text), ...
                    '^(\d+)\s+((?:[-+]?\d+\.\d+[DEde][-+]?\d+\s*)+)$', ...
                    'tokens','once');
                if isempty(match)
                    if ~isempty(columns)&&any(hessian,"all"),break,end
                    index=index+1;continue
                end
                row=str2double(match{1});
                rowValues=numbers(match{2});
                usable=min(numel(columns),numel(rowValues));
                for valueIndex=1:usable
                    column=columns(valueIndex);
                    if row<=dimension&&column<=dimension
                        hessian(row,column)=rowValues(valueIndex);
                        hessian(column,row)=rowValues(valueIndex);
                    end
                end
                index=index+1;
            end
        end

        function matrix=parseBondOrders(~,lines,inputStructures)
            matrix=zeros(0);
            header=find(contains(lines, ...
                "Wiberg bond index matrix in the NAO basis:"),1,"last");
            if isempty(header)||isempty(inputStructures),return,end
            count=inputStructures{1}.num_sites;
            matrix=zeros(count);index=header+1;rows=0;
            while index<=numel(lines)&&rows<count
                values=numbers(lines(index));
                if numel(values)>=count+1
                    row=round(values(1));
                    if row>=1&&row<=count
                        matrix(row,:)=values(end-count+1:end);
                        rows=rows+1;
                    end
                end
                index=index+1;
            end
        end

        function resumes=parseResumes(~,lines)
            resumes=cell(1,0);index=1;
            while index<=numel(lines)
                if ~isempty(regexp(char(lines(index)), ...
                        '^\s*1\\1\\GINC-\S*','once'))
                    pieces=strings(0,1);
                    while index<=numel(lines)
                        pieces(end+1)=strtrim(lines(index)); %#ok<AGROW>
                        if contains(lines(index),"\\@"),break,end
                        index=index+1;
                    end
                    resumes{end+1}=char(join(pieces,"")); %#ok<AGROW>
                end
                index=index+1;
            end
        end

        function charges=parseMulliken(~,lines)
            charges=containers.Map("KeyType","double","ValueType","any");
            active=false;
            for index=1:numel(lines)
                if ~active&&(contains(lines(index),"Mulliken charges")|| ...
                        contains(lines(index),"Mulliken atomic charges"))
                    active=true;continue
                end
                if active&&contains(lines(index),"Sum of Mulliken")
                    active=false;continue
                end
                if active
                    match=regexp(char(lines(index)), ...
                        '^\s*(\d+)\s+([A-Z][a-z]?)\s*(\S+)', ...
                        'tokens','once');
                    if ~isempty(match)
                        charges(str2double(match{1}))= ...
                            {match{2},str2double(match{3})};
                    end
                end
            end
        end

        function value=mapPairs(~,map)
            names=sort(string(keys(map)));value=cell(numel(names),2);
            for index=1:numel(names)
                value{index,1}=char(names(index));
                item=map(char(names(index)));
                if isa(item,"containers.Map")
                    nested=sort(string(keys(item)));
                    pairs=cell(numel(nested),2);
                    for nestedIndex=1:numel(nested)
                        pairs{nestedIndex,1}=char(nested(nestedIndex));
                        pairs{nestedIndex,2}= ...
                            item(char(nested(nestedIndex)));
                    end
                    item=pairs;
                end
                value{index,2}=item;
            end
        end

        function tf=mapHas(~,map,name)
            tf=any(strcmpi(keys(map),name));
        end

        function filename=ensureExtension(~,filename,imgFormat)
            filename=string(filename);imgFormat=string(imgFormat);
            [~,~,extension]=fileparts(filename);
            if strlength(extension)==0,filename=filename+"."+imgFormat;end
        end
    end
end

function [molecule,nextIndex]=orientationBlock(lines,startIndex)
index=startIndex+1;dashCount=0;
while index<=numel(lines)
    if ~isempty(regexp(char(strtrim(lines(index))),'^-+$','once'))
        dashCount=dashCount+1;
        if dashCount==2,index=index+1;break,end
    end
    index=index+1;
end
species=cell(1,0);coordinates=zeros(0,3);
while index<=numel(lines)&& ...
        isempty(regexp(char(strtrim(lines(index))),'^-+$','once'))
    tokens=split(strtrim(lines(index)));
    if numel(tokens)>=6
        atomicNumber=str2double(tokens(2));
        xyz=str2double(tokens(4:6));
        if isfinite(atomicNumber)&&all(isfinite(xyz))
            species{end+1}=atomicNumber; %#ok<AGROW>
            coordinates(end+1,:)=reshape(xyz,1,3); %#ok<AGROW>
        end
    end
    index=index+1;
end
if isempty(species)
    error("KSSOLV:Matgenlab:GaussianOutput:Orientation", ...
        "Malformed Gaussian orientation block.");
end
molecule=kssolv.analysis.matgenlab.core.Molecule(species,coordinates);
nextIndex=index+1;
end

function value=numbers(text)
tokens=regexp(char(strjoin(string(text)," ")), ...
    '[-+]?(?:\d+\.\d*|\.\d+|\d+)(?:[EeDd][-+]?\d+)?','match');
value=str2double(strrep(tokens,"D","E"));
end

function value=floatNumbers(text)
tokens=regexp(char(strjoin(string(text)," ")), ...
    '[-+]?\d+\.\d+(?:[EeDd][-+]?\d+)?','match');
value=str2double(strrep(tokens,"D","E"));
end

function value=itemAt(values,index)
if numel(values)>=index,value=values(index);else,value=NaN;end
end

function text=readOutputText(filename)
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
