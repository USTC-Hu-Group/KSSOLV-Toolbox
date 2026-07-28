classdef CoherentInterfaceBuilder
    %COHERENTINTERFACEBUILDER Construct lattice-matched crystalline interfaces.
    properties (SetAccess=private)
        substrate_structure
        film_structure
        film_miller (1,3) double
        substrate_miller (1,3) double
        zslgen
        termination_ftol
        label_index (1,1) logical
        filter_out_sym_slabs (1,1) logical
        zsl_matches cell
        terminations cell
        film_termination_ftol (1,1) double
        substrate_termination_ftol (1,1) double
    end
    properties (Access=private)
        terminationShifts
    end
    methods
        function obj=CoherentInterfaceBuilder( ...
                substrateStructure,filmStructure,filmMiller, ...
                substrateMiller,zslGenerator,terminationTolerance, ...
                labelIndex,filterSymmetric)
            obj.substrate_structure=substrateStructure;
            obj.film_structure=filmStructure;
            obj.film_miller=reshape(double(filmMiller),1,3);
            obj.substrate_miller=reshape(double(substrateMiller),1,3);
            if nargin<5||isempty(zslGenerator)
                zslGenerator=kssolv.analysis.matgenlab.analysis. ...
                    interfaces.ZSLGenerator(.09,400,.03,.01,true);
            end
            if nargin<6||isempty(terminationTolerance)
                terminationTolerance=.25;
            end
            if nargin<7||isempty(labelIndex),labelIndex=false;end
            if nargin<8||isempty(filterSymmetric),filterSymmetric=true;end
            obj.zslgen=zslGenerator;
            obj.termination_ftol=terminationTolerance;
            obj.label_index=labelIndex;
            obj.filter_out_sym_slabs=filterSymmetric;
            obj=obj.findMatches();
            obj=obj.findTerminations();
        end

        function interfaces=get_interfaces(obj,termination,gap, ...
                vacuumOverFilm,filmThickness,substrateThickness,inLayers)
            if nargin<3||isempty(gap),gap=2;end
            if nargin<4||isempty(vacuumOverFilm),vacuumOverFilm=20;end
            if nargin<5||isempty(filmThickness),filmThickness=1;end
            if nargin<6||isempty(substrateThickness)
                substrateThickness=1;
            end
            if nargin<7||isempty(inLayers),inLayers=true;end
            key=terminationKey(termination);
            if ~isKey(obj.terminationShifts,key)
                error("KSSOLV:Matgenlab:CoherentInterface:Termination", ...
                    "Unknown interface termination.");
            end
            shifts=obj.terminationShifts(key);
            filmGenerator=makeGenerator(obj.film_structure, ...
                obj.film_miller,filmThickness,inLayers);
            substrateGenerator=makeGenerator(obj.substrate_structure, ...
                obj.substrate_miller,substrateThickness,inLayers);
            filmSlab=filmGenerator.get_slab(shifts(1));
            substrateSlab=substrateGenerator.get_slab(shifts(2));
            if isempty(obj.zsl_matches)
                error("KSSOLV:Matgenlab:CoherentInterface:NoMatch", ...
                    "No ZSL matches were found.");
            end
            interfaces=cell(1,numel(obj.zsl_matches));
            for index=1:numel(obj.zsl_matches)
                match=obj.zsl_matches{index};
                filmTransform=round( ...
                    kssolv.analysis.matgenlab.analysis.interfaces. ...
                    from_2d_to_3d( ...
                    kssolv.analysis.matgenlab.analysis.interfaces. ...
                    get_2d_transform( ...
                    filmSlab.lattice.matrix(1:2,:), ...
                    match.film_sl_vectors)));
                filmSupercell=filmSlab.copy();
                filmSupercell=filmSupercell.make_supercell(filmTransform);
                substrateTransform=round( ...
                    kssolv.analysis.matgenlab.analysis.interfaces. ...
                    from_2d_to_3d( ...
                    kssolv.analysis.matgenlab.analysis.interfaces. ...
                    get_2d_transform( ...
                    substrateSlab.lattice.matrix(1:2,:), ...
                    match.substrate_sl_vectors)));
                substrateSupercell=substrateSlab.copy();
                substrateSupercell= ...
                    substrateSupercell.make_supercell(substrateTransform);
                verifySupercell(filmSupercell,filmSlab, ...
                    match.film_sl_vectors,"film");
                verifySupercell(substrateSupercell,substrateSlab, ...
                    match.substrate_sl_vectors,"substrate");
                deformation=kssolv.analysis.matgenlab.core.Deformation( ...
                    match.match_transformation);
                strain=deformation.green_lagrange_strain;
                properties=match.as_dict();
                properties=rmfield(properties, ...
                    intersect(fieldnames(properties), ...
                    {'x_module','x_class'}));
                properties.strain=strain;
                properties.von_mises_strain=strain.von_mises_strain;
                properties.termination=termination;
                properties.film_thickness=filmThickness;
                properties.substrate_thickness=substrateThickness;
                interfaces{index}= ...
                    kssolv.analysis.matgenlab.core.Interface.from_slabs( ...
                    substrateSupercell,filmSupercell, ...
                    "in_plane_offset",[0,0],"gap",gap, ...
                    "vacuum_over_film",vacuumOverFilm, ...
                    "interface_properties",properties,"center_slab",true);
            end
        end
    end
    methods (Access=private)
        function obj=findMatches(obj)
            filmGenerator=makeGenerator( ...
                obj.film_structure,obj.film_miller,1,true);
            substrateGenerator=makeGenerator( ...
                obj.substrate_structure,obj.substrate_miller,1,true);
            film=filmGenerator.get_slab(0);
            substrate=substrateGenerator.get_slab(0);
            obj.zsl_matches=obj.zslgen.call( ...
                film.lattice.matrix(1:2,:), ...
                substrate.lattice.matrix(1:2,:),false);
            for index=1:numel(obj.zsl_matches)
                match=obj.zsl_matches{index};
                assertIntegerTransform(film.lattice.matrix, ...
                    match.film_vectors,"film");
                assertIntegerTransform(substrate.lattice.matrix, ...
                    match.substrate_vectors,"substrate");
            end
        end

        function obj=findTerminations(obj)
            if isscalar(obj.termination_ftol)
                obj.film_termination_ftol=obj.termination_ftol;
                obj.substrate_termination_ftol=obj.termination_ftol;
            else
                tolerances=reshape(double(obj.termination_ftol),1,2);
                obj.film_termination_ftol=tolerances(1);
                obj.substrate_termination_ftol=tolerances(2);
            end
            filmGenerator=makeGenerator( ...
                obj.film_structure,obj.film_miller,1,true);
            substrateGenerator=makeGenerator( ...
                obj.substrate_structure,obj.substrate_miller,1,true);
            filmSlabs=filmGenerator.get_slabs( ...
                "ftol",obj.film_termination_ftol, ...
                "filter_out_sym_slabs",obj.filter_out_sym_slabs);
            substrateSlabs=substrateGenerator.get_slabs( ...
                "ftol",obj.substrate_termination_ftol, ...
                "filter_out_sym_slabs",obj.filter_out_sym_slabs);
            obj.terminations=cell(0,2);
            obj.terminationShifts=containers.Map( ...
                "KeyType","char","ValueType","any");
            for filmIndex=1:numel(filmSlabs)
                filmLabel=kssolv.analysis.matgenlab.core. ...
                    label_termination(filmSlabs{filmIndex}, ...
                    obj.film_termination_ftol, ...
                    labelIndex(obj.label_index,filmIndex));
                for substrateIndex=1:numel(substrateSlabs)
                    substrateLabel=kssolv.analysis.matgenlab.core. ...
                        label_termination(substrateSlabs{substrateIndex}, ...
                        obj.substrate_termination_ftol, ...
                        labelIndex(obj.label_index,substrateIndex));
                    pair={char(filmLabel),char(substrateLabel)};
                    obj.terminations(end+1,:)=pair;
                    obj.terminationShifts(terminationKey(pair))= ...
                        [filmSlabs{filmIndex}.shift, ...
                        substrateSlabs{substrateIndex}.shift];
                end
            end
        end
    end
end

function generator=makeGenerator(structure,miller,thickness,inLayers)
generator=kssolv.analysis.matgenlab.core.SlabGenerator( ...
    structure,miller,thickness,3, ...
    "lll_reduce",false,"center_slab",true, ...
    "in_unit_planes",inLayers,"primitive",true, ...
    "max_normal_search",[],"reorient_lattice",false);
end

function value=labelIndex(enabled,index)
if enabled,value=index;else,value=[];end
end

function key=terminationKey(pair)
if isstring(pair),pair=cellstr(pair);end
key=strjoin(string(pair),char(31));
key=char(key);
end

function assertIntegerTransform(start,target,kind)
transformation=kssolv.analysis.matgenlab.analysis.interfaces. ...
    get_2d_transform(start,target);
[left,~,right]=svd(transformation,"econ");
unitary=left*right';
if any(abs(unitary-round(unitary))>1e-7,"all")
    error("KSSOLV:Matgenlab:CoherentInterface:ChangedVectors", ...
        "%s lattice vectors changed during ZSL matching.",kind);
end
end

function verifySupercell(supercell,source,vectors,kind)
if norm(supercell.lattice.matrix(3,:)- ...
        source.lattice.matrix(3,:))>1e-7
    error("KSSOLV:Matgenlab:CoherentInterface:Caxis", ...
        "The %s supercell transform changed the c axis.",kind);
end
if max(abs(supercell.lattice.matrix(1:2,:)-vectors),[],"all")>1e-7
    error("KSSOLV:Matgenlab:CoherentInterface:Supercell", ...
        "The %s supercell does not reproduce matched vectors.",kind);
end
end
