classdef CrystalSceneValidator
    %CRYSTALSCENEVALIDATOR Enforce CrystalSceneSpec scientific invariants.
    methods (Static)
        function validate(scene)
            required = ["schemaVersion", "kind", "requestId", "sites", ...
                "atomInstances", "bondRelations", "bondInstances", ...
                "polyhedra", "analysis", "warnings"];
            missing = required(~isfield(scene, required));
            if ~isempty(missing)
                error("KSSOLV:CrystalViewer:SceneSchema", ...
                    "Scene is missing fields: %s.", join(missing, ", "));
            end
            if string(scene.schemaVersion) ~= "2.0"
                error("KSSOLV:CrystalViewer:SceneVersion", ...
                    "Unsupported AtomicSceneSpec version '%s'.", ...
                    string(scene.schemaVersion));
            end
            kind = string(scene.kind);
            if kind == "crystal"
                if isfield(scene, "molecule")
                    error("KSSOLV:CrystalViewer:SceneSchema", ...
                        "A crystal scene cannot contain molecule metadata.");
                end
                if ~isfield(scene, "structure")
                    error("KSSOLV:CrystalViewer:SceneSchema", ...
                        "A crystal scene requires structure metadata.");
                end
                if ~isequal(size(scene.structure.lattice), [3, 3]) || ...
                        any(~isfinite(scene.structure.lattice), "all")
                    error("KSSOLV:CrystalViewer:Lattice", ...
                        "Scene lattice must be a finite 3-by-3 matrix.");
                end
                if abs(det(scene.structure.lattice)) <= eps
                    error("KSSOLV:CrystalViewer:Lattice", ...
                        "Scene lattice must be nonsingular.");
                end
                siteCount = scene.structure.siteCount;
            elseif kind == "molecule"
                if isfield(scene, "structure")
                    error("KSSOLV:CrystalViewer:SceneSchema", ...
                        "A molecule scene cannot contain crystal lattice metadata.");
                end
                if ~isfield(scene, "molecule")
                    error("KSSOLV:CrystalViewer:SceneSchema", ...
                        "A molecule scene requires molecule metadata.");
                end
                siteCount = scene.molecule.atomCount;
                if ~isfinite(scene.molecule.charge) || ...
                        scene.molecule.spinMultiplicity < 1
                    error("KSSOLV:CrystalViewer:MoleculeMetadata", ...
                        "Molecular charge and spin metadata are invalid.");
                end
            else
                error("KSSOLV:CrystalViewer:SceneKind", ...
                    "Unsupported atomic scene kind '%s'.", kind);
            end
            if numel(scene.sites) ~= siteCount
                error("KSSOLV:CrystalViewer:SiteCount", ...
                    "Scene site count does not match its site array.");
            end
            if ~isempty(scene.sites)
                indices = [scene.sites.siteIndex];
                if ~isequal(sort(indices), 0:numel(scene.sites)-1)
                    error("KSSOLV:CrystalViewer:SiteIndex", ...
                        "Scene site indices must be unique and zero based.");
                end
            end
            kssolv.ui.scene.atomic.CrystalSceneValidator. ...
                validateRelations(scene);
            kssolv.ui.scene.atomic.CrystalSceneValidator. ...
                validateInstances(scene);
        end
    end

    methods (Static, Access = private)
        function validateRelations(scene)
            siteCount = ...
                kssolv.ui.scene.atomic.CrystalSceneValidator.siteCount(scene);
            keys = strings(1, numel(scene.bondRelations));
            for index = 1:numel(scene.bondRelations)
                relation = scene.bondRelations(index);
                if relation.fromSiteIndex < 0 || ...
                        relation.toSiteIndex < 0 || ...
                        relation.fromSiteIndex >= siteCount || ...
                        relation.toSiteIndex >= siteCount
                    error("KSSOLV:CrystalViewer:BondSite", ...
                        "Bond relation %d references an unknown site.", index);
                end
                if relation.distance <= 0 || ~isfinite(relation.distance)
                    error("KSSOLV:CrystalViewer:BondDistance", ...
                        "Bond relation %d has an invalid distance.", index);
                end
                keys(index) = string(relation.fromSiteIndex) + "::" + ...
                    string(relation.toSiteIndex) + "::" + ...
                    join(string(relation.relativeImage), ",");
            end
            if numel(unique(keys)) ~= numel(keys)
                error("KSSOLV:CrystalViewer:DuplicateRelation", ...
                    "Scene contains duplicate scientific bond relations.");
            end
        end

        function validateInstances(scene)
            siteCount = ...
                kssolv.ui.scene.atomic.CrystalSceneValidator.siteCount(scene);
            atomKeys = strings(1, numel(scene.atomInstances));
            for index = 1:numel(scene.atomInstances)
                atom = scene.atomInstances(index);
                if atom.siteIndex < 0 || ...
                        atom.siteIndex >= siteCount
                    error("KSSOLV:CrystalViewer:AtomSite", ...
                        "Atom instance %d references an unknown site.", index);
                end
                if any(~isfinite(atom.position))
                    error("KSSOLV:CrystalViewer:AtomPosition", ...
                        "Atom instance %d has a non-finite position.", index);
                end
                atomKeys(index) = string(atom.siteIndex) + "@" + ...
                    join(string(atom.imageOffset), ",");
            end
            if numel(unique(atomKeys)) ~= numel(atomKeys)
                error("KSSOLV:CrystalViewer:DuplicateAtom", ...
                    "Scene contains duplicate atom instances.");
            end
            for index = 1:numel(scene.bondInstances)
                bond = scene.bondInstances(index);
                measured = norm(bond.end - bond.start);
                if abs(measured - bond.distance) > 1e-8
                    error("KSSOLV:CrystalViewer:BondGeometry", ...
                        "Bond instance %d distance is inconsistent.", index);
                end
            end
        end

        function value = siteCount(scene)
            if string(scene.kind) == "crystal"
                value = scene.structure.siteCount;
            else
                value = scene.molecule.atomCount;
            end
        end
    end
end
