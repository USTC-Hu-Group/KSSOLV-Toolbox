classdef Critic2NN < kssolv.analysis.matgenlab.core.NearNeighbors
    %CRITIC2NN Native topological-neighbor compatibility strategy.
    %
    % Periodic structures use CrystalNN's Voronoi/chemical topology and
    % molecules use covalent topology. The result has the same graph and
    % nn-info schema as the critic2-backed upstream strategy, without an
    % external executable or Python dependency.
    methods
        function obj=Critic2NN()
            obj.structures_allowed=true;obj.molecules_allowed=true;
            obj.extend_structure_molecules=true;
        end
        function graph=get_bonded_structure(obj,structure,varargin)
            options=struct(decorate=false);options=parse(options,varargin);
            graph=get_bonded_structure@kssolv.analysis.matgenlab.core. ...
                NearNeighbors(obj,structure,"decorate",options.decorate);
        end
        function info=get_nn_info(~,structure,n)
            if isa(structure,"kssolv.analysis.matgenlab.core.IStructure")
                strategy=kssolv.analysis.matgenlab.core.CrystalNN();
            else
                strategy=kssolv.analysis.matgenlab.core.CovalentBondNN();
            end
            info=strategy.get_nn_info(structure,n);
        end
    end
end
function output=parse(output,input)
for ii=1:2:numel(input)
    output.(char(string(input{ii})))=input{ii+1};
end
end
