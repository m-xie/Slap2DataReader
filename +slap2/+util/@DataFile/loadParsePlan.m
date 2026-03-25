function loadParsePlan(obj)
    AC = obj.metaData.AcquisitionContainer;

    hasParsePlan = checkField(AC, 'ParsePlan');
    hasAcquisitionPlan = checkField(AC, 'AcquisitionPlan');

    if hasParsePlan
        % Master branch format: AcquisitionContainer has a ParsePlan with
        % pre-aggregated per-line structs and zero-based slice indices.
        loadParsePlanMaster(obj, AC);
    elseif hasAcquisitionPlan
        % fastZFeedbackExperiment3 branch format: AcquisitionContainer has
        % a single AcquisitionPlan with activeZs and superPixelIDs (the
        % latter may be absent when loaded without the class definition
        % since it is a Dependent property).
        loadParsePlanFastZ(obj, AC);
    else
        error('Slap2DataFile:UnknownMetaFormat', ...
            'Metadata does not contain a recognized acquisition plan (expected ParsePlan or AcquisitionPlan).');
    end
end

%% Master branch (ParsePlan)
function loadParsePlanMaster(obj, AC)
    obj.fastZs = AC.ParsePlan.zs;
    obj.lineSuperPixelIDs = {AC.ParsePlan.acqParsePlan.superPixelID}';
    obj.lineSuperPixelZIdxs = {AC.ParsePlan.acqParsePlan.sliceIdx}';
    obj.zPixelReplacementMaps = AC.ParsePlan.pixelReplacementMaps;
    obj.zPixelReplacementMapsNonRedundant = filterZPixelReplacementMaps(obj.zPixelReplacementMaps);
    obj.lineNumSuperPixels = cellfun('prodofsize', obj.lineSuperPixelIDs);

    obj.lineFastZIdxs = zeros(size(obj.lineSuperPixelZIdxs), 'uint32');
    for lineIdx = 1:numel(obj.lineSuperPixelZIdxs)
        lineZIdxs_ = obj.lineSuperPixelZIdxs{lineIdx};
        if isempty(lineZIdxs_)
            obj.lineFastZIdxs(lineIdx) = 0;
        else
            obj.lineFastZIdxs(lineIdx) = lineZIdxs_(1) + 1; % 0-based -> 1-based
        end
    end
end

%% fastZFeedbackExperiment3 branch (AcquisitionPlan)
function loadParsePlanFastZ(obj, AC)
    plan = AC.AcquisitionPlan;

    aZs = plan.activeZs;
    if ~iscell(aZs), aZs = num2cell(aZs, 2); end
    nonEmpty = ~cellfun(@isempty, aZs);
    allZ = cell2mat(cellfun(@(x) x(:), aZs(nonEmpty), 'uni', false));
    obj.fastZs = unique(allZ);

    % superPixelIDs is a Dependent property in the AcquisitionPlan class.
    % When the .meta file is loaded without the class on the MATLAB path,
    % the object is degraded to a struct and superPixelIDs will be absent.
    % Fall back to computing it from activeSuperPixels.
    try
        spIDs = plan.superPixelIDs;
    catch
        spIDs = deriveSuperPixelIDs(plan.activeSuperPixels);
    end
    if ~iscell(spIDs), spIDs = num2cell(spIDs, 2); end
    obj.lineSuperPixelIDs = spIDs(:);

    obj.lineSuperPixelZIdxs = aZs(:);

    prm = plan.pixelReplacementMaps;
    if ~iscell(prm), prm = {prm}; end
    obj.zPixelReplacementMaps = prm(:);
    obj.zPixelReplacementMapsNonRedundant = filterZPixelReplacementMaps(obj.zPixelReplacementMaps);

    obj.lineNumSuperPixels = cellfun('prodofsize', obj.lineSuperPixelIDs);

    % activeZs values are already 1-based in this format (no +1 needed)
    nLines = numel(obj.lineSuperPixelZIdxs);
    obj.lineFastZIdxs = zeros(nLines, 1, 'uint32');
    for lineIdx = 1:nLines
        z = obj.lineSuperPixelZIdxs{lineIdx};
        if isempty(z)
            obj.lineFastZIdxs(lineIdx) = 0;
        else
            obj.lineFastZIdxs(lineIdx) = z(1);
        end
    end
end

%% Helpers
function spIDs = deriveSuperPixelIDs(activeSuperPixels)
    spIDs = cell(size(activeSuperPixels));
    for idx = 1:numel(activeSuperPixels)
        linePixels = activeSuperPixels{idx};
        if isempty(linePixels)
            spIDs{idx} = zeros(1, 0, 'uint32');
        else
            spIDs{idx} = cellfun(@(p) p(1), linePixels);
        end
    end
end

function tf = checkField(s, name)
    tf = false;
    if isstruct(s)
        tf = isfield(s, name) && ~isempty(s.(name));
    elseif isobject(s)
        tf = isprop(s, name) && ~isempty(s.(name));
    end
end

function zMaps = filterZPixelReplacementMaps(zMaps)
    if ~iscell(zMaps), zMaps = {zMaps}; end
    for iSliceMap = 1:numel(zMaps)
        sliceMap = zMaps{iSliceMap};
        redundantMask = sliceMap(:, 1) == sliceMap(:, 2);
        sliceMap(redundantMask, :) = [];
        zMaps{iSliceMap} = sliceMap;
    end
end
