classdef CutOffDictNN < kssolv.analysis.matgenlab.core.NearNeighbors
    %#ok<*ALIGN>
    properties
        cut_off_dict
    end
    properties (Access=private)
        lookup_
        max_dist_ (1,1) double=0
        vesta_preset_ (1,1) logical=false
    end
    methods
        function obj=CutOffDictNN(cut_off_dict)
            obj.structures_allowed=true;obj.molecules_allowed=true;
            obj.extend_structure_molecules=true;
            obj.lookup_=containers.Map("KeyType","char","ValueType","double");
            if nargin<1||isempty(cut_off_dict),cut_off_dict={};end
            obj.cut_off_dict=cut_off_dict;
            if iscell(cut_off_dict)
                if size(cut_off_dict,2)~=3&&~isempty(cut_off_dict)
                    error("KSSOLV:Matgenlab:CutOffDictNN:Shape", ...
                        "Cell cut-off data must contain species1, species2, distance.");
                end
                for ii=1:size(cut_off_dict,1)
                    obj=obj.addPair(cut_off_dict{ii,1},cut_off_dict{ii,2}, ...
                        cut_off_dict{ii,3});
                end
            elseif isstruct(cut_off_dict)
                names=fieldnames(cut_off_dict);
                for ii=1:numel(names)
                    parts=split(string(names{ii}),"_");
                    if numel(parts)~=2,continue,end
                    obj=obj.addPair(parts(1),parts(2),cut_off_dict.(names{ii}));
                end
            elseif isa(cut_off_dict,"containers.Map")
                names=keys(cut_off_dict);
                for ii=1:numel(names)
                    parts=split(string(names{ii}),[",","-","_"]);
                    parts=parts(strlength(parts)>0);
                    if numel(parts)==2,obj=obj.addPair(parts(1),parts(2),cut_off_dict(names{ii}));end
                end
            end
        end
        function info=get_nn_info(obj,structure,n)
            info={};if obj.max_dist_<=0,return,end
            center=structure(n);neighbors=structure.get_neighbors(center,obj.max_dist_);
            for ii=1:numel(neighbors)
                key=obj.key(center.species_string,neighbors{ii}.species_string);
                limit=NaN;
                if isKey(obj.lookup_,key),limit=obj.lookup_(key);
                elseif obj.vesta_preset_,limit=obj.vestaCutoff( ...
                        center.specie.symbol,neighbors{ii}.specie.symbol);end
                if ~isnan(limit)&&neighbors{ii}.nn_distance<limit
                    info{end+1}=obj.makeInfo(neighbors{ii},neighbors{ii}.nn_distance); %#ok<AGROW>
                end
            end
        end
    end
    methods (Static)
        function obj=from_preset(preset)
            if string(preset)~="vesta_2019"
                error("KSSOLV:Matgenlab:CutOffDictNN:Preset", ...
                    "Unknown preset '%s'.",string(preset));
            end
            obj=kssolv.analysis.matgenlab.core.CutOffDictNN();
            obj.vesta_preset_=true;obj.max_dist_=5;
        end
    end
    methods (Access=private)
        function obj=addPair(obj,first,second,distance)
            obj.lookup_(obj.key(first,second))=double(distance);
            obj.lookup_(obj.key(second,first))=double(distance);
            obj.max_dist_=max(obj.max_dist_,double(distance));
        end
        function value=key(~,first,second)
            value=char(string(first)+"::"+string(second));
        end
        function value=vestaCutoff(~,first,second)
            % VESTA 2019 is a sparse table derived from bond radii. Preserve
            % its exact common light-element entries and use the same
            % radius-sum construction for uncommon pairs.
            pair=sort([string(first),string(second)]);
            exact=containers.Map( ...
                {'C::C','Br::C','C::Cl','C::F','C::H','C::I','C::N', ...
                 'C::O','C::P','C::S','C::Se','C::Te'}, ...
                {1.89002,2.26002,2.11002,1.76002,1.2,2.16998, ...
                 1.79202,1.97249,1.93998,2.15002,2.01998,2.25998});
            key=char(pair(1)+"::"+pair(2));
            if isKey(exact,key),value=exact(key);return,end
            radii=kssolv.analysis.matgenlab.core.CovalentRadius.radius();
            a=matlab.lang.makeValidName(char(pair(1)));
            b=matlab.lang.makeValidName(char(pair(2)));
            if isfield(radii,a)&&isfield(radii,b)
                value=radii.(a)+radii.(b)+.37;
            else,value=NaN;end
        end
    end
end
