function loadParsePlan(obj)
    AC = obj.metaData.AcquisitionContainer;

    newFormat = isfield(AC, 'AcquisitionPlan') ...
             && isstruct(AC.AcquisitionPlan)   ...
             && isfield(AC.AcquisitionPlan, 'superPixelIDs');

    if newFormat
        loadParsePlanNew(obj, AC);
    else
        loadParsePlanOld(obj, AC);
    end
end

function loadParsePlanOld(obj, AC)
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

function loadParsePlanNew(obj, AC)
    plan = AC.AcquisitionPlan;

    aZs = plan.activeZs;
    if ~iscell(aZs), aZs = num2cell(aZs, 2); end
    nonEmpty = ~cellfun(@isempty, aZs);
    allZ = cell2mat(cellfun(@(x) x(:), aZs(nonEmpty), 'uni', false));
    obj.fastZs = unique(allZ);

    spIDs = plan.superPixelIDs;
    if ~iscell(spIDs), spIDs = num2cell(spIDs, 2); end
    obj.lineSuperPixelIDs = spIDs(:);

    obj.lineSuperPixelZIdxs = aZs(:);

    prm = plan.pixelReplacementMaps;
    if ~iscell(prm), prm = {prm}; end
    obj.zPixelReplacementMaps = prm(:);
    obj.zPixelReplacementMapsNonRedundant = filterZPixelReplacementMaps(obj.zPixelReplacementMaps);

    obj.lineNumSuperPixels = cellfun('prodofsize', obj.lineSuperPixelIDs);

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

function zMaps = filterZPixelReplacementMaps(zMaps)
    if ~iscell(zMaps), zMaps = {zMaps}; end
    for iSliceMap = 1:numel(zMaps)
        sliceMap = zMaps{iSliceMap};
        redundantMask = sliceMap(:, 1) == sliceMap(:, 2);
        sliceMap(redundantMask, :) = [];
        zMaps{iSliceMap} = sliceMap;
    end
end
