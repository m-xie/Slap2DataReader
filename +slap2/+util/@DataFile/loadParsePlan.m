function loadParsePlan(obj)
    AC = obj.metaData.AcquisitionContainer;

    hasParsePlan = checkField(AC, 'ParsePlan');
    hasAcquisitionPlan = checkField(AC, 'AcquisitionPlan');

    if hasParsePlan
        loadParsePlanMaster(obj, AC);
    elseif hasAcquisitionPlan
        loadParsePlanFastZ(obj, AC);
    else
        error('Slap2DataFile:UnknownMetaFormat', ...
            'Metadata does not contain a recognized acquisition plan (expected ParsePlan or AcquisitionPlan).');
    end
end

%% Master branch (ParsePlan) — matches slap2 master:+slap2/+util/@DataFile/loadParsePlan.m
function loadParsePlanMaster(obj, AC)
    obj.fastZs = AC.ParsePlan.zs;
    obj.lineSuperPixelIDs = {AC.ParsePlan.acqParsePlan.superPixelID} .';
    obj.lineSuperPixelZIdxs = {AC.ParsePlan.acqParsePlan.sliceIdx} .';
    obj.zPixelReplacementMaps = AC.ParsePlan.pixelReplacementMaps;
    obj.zPixelReplacementMapsNonRedundant = filterZPixelReplacementMaps(obj.zPixelReplacementMaps);
    obj.lineNumSuperPixels = cellfun('prodofsize', obj.lineSuperPixelIDs);

    obj.lineFastZIdxs = zeros(size(obj.lineSuperPixelZIdxs), 'uint32');
    for lineIdx = 1:numel(obj.lineSuperPixelZIdxs)
        lineZIdxs_ = obj.lineSuperPixelZIdxs{lineIdx}; % assume all superPixels in a line are on same Z
        if isempty(lineZIdxs_)
            obj.lineFastZIdxs(lineIdx) = 0;
        else
            obj.lineFastZIdxs(lineIdx) = lineZIdxs_(1) + 1; % convert to one based indexing
        end
    end
end

%% fastZFeedbackExperiment3 branch (AcquisitionPlan) — matches slap2 fastZFeedbackEperiment3:+slap2/+util/@DataFile/loadParsePlan.m
function loadParsePlanFastZ(obj, AC)
    AcquisitionPlan = AC.AcquisitionPlan;

    zs = horzcat(AcquisitionPlan.activeZs{:});
    zs = unique(zs);

    obj.fastZs = zs;
    obj.lineSuperPixelIDs = AcquisitionPlan.superPixelIDs;
    obj.lineSuperPixelZIdxs = AcquisitionPlan.activeZs;
    obj.zPixelReplacementMaps = AcquisitionPlan.pixelReplacementMaps;
    obj.zPixelReplacementMapsNonRedundant = filterZPixelReplacementMaps(obj.zPixelReplacementMaps);
    obj.lineNumSuperPixels = cellfun('prodofsize', obj.lineSuperPixelIDs);

    obj.lineFastZIdxs = zeros(size(obj.lineSuperPixelZIdxs), 'uint32');
    for lineIdx = 1:numel(obj.lineSuperPixelZIdxs)
        lineZIdxs_ = obj.lineSuperPixelZIdxs{lineIdx}; % assume all superPixels in a line are on same Z
        if isempty(lineZIdxs_)
            obj.lineFastZIdxs(lineIdx) = 0;
        else
            obj.lineFastZIdxs(lineIdx) = lineZIdxs_(1);
        end
    end
end

function zMaps = filterZPixelReplacementMaps(zMaps)
    for iSliceMap = 1:numel(zMaps)
        sliceMap = zMaps{iSliceMap};
        redundantMask = sliceMap(:, 1) == sliceMap(:, 2);
        sliceMap(redundantMask, :) = [];
        zMaps{iSliceMap} = sliceMap;
    end
end

%% Helpers (Slap2DataReader-specific)
function tf = checkField(s, name)
    tf = false;
    if isstruct(s)
        tf = isfield(s, name) && ~isempty(s.(name));
    elseif isobject(s)
        tf = isprop(s, name) && ~isempty(s.(name));
    end
end
