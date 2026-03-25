function lineData = getLineData(obj, lineIndices, cycleIndices, iChannel)
    arguments
        obj;
        lineIndices(:,1) double {mustBeVector, mustBePositive, mustBeInteger};
        cycleIndices(:,1) double {mustBeVector, mustBePositive, mustBeInteger};
        iChannel(1,:) double {mustBeVector, mustBePositive, mustBeInteger} = 1:obj.header.numChannels;
    end

    validateattributes(lineIndices, {'numeric'}, {'<=', obj.header.linesPerCycle}, ...
        'getLineData', 'line indices', 2);
    validateattributes(cycleIndices, {'numeric'}, {'<=', obj.numCycles, 'numel', length(lineIndices)}, ...
        'getLineData', 'cycle indices', 3);
    validateattributes(iChannel, {'numeric'}, {'<=', obj.header.numChannels}, ...
        'getLineData', 'channelIdxs', 4);

    assert(~obj.header.channelsInterleave,'Only deinterleaved data is supported')

    cycleOffset      = (cycleIndices - 1) * obj.header.bytesPerCycle / 2;
    lineStartIndices = obj.lineDataStartIdxs(lineIndices) + cycleOffset;
    lineNumElements  = obj.lineDataNumElements(lineIndices);

    if obj.useMex
        lineData = getSegmentedDataMex(obj, lineStartIndices, lineNumElements, iChannel);
    else
        lineData = getSegmentedDataMmap(obj, lineStartIndices, lineNumElements, iChannel);
    end
end

%% MEX path — matches slap2:+slap2/+util/@DataFile/getLineData.m
function lineData = getSegmentedDataMex(obj, lineStartIndices, lineNumElements, iChannel)
    channelLineNumElements = lineNumElements ./ obj.header.numChannels;
    channelOffsets = iChannel - 1;
    lineOffsetIndices = min(channelOffsets) .* channelLineNumElements;

    channelRange = diff([min(channelOffsets), max(channelOffsets)]) + 1;
    totalLineSizes = channelLineNumElements .* channelRange;
    totalLineStartIndices = (lineStartIndices - 1) + lineOffsetIndices;
    lineRanges = uint64([totalLineStartIndices, totalLineSizes]);
    numQueriedChannels = numel(iChannel);

    lineData = MexFetchImageData('GETDATA', obj.StreamId, lineRanges);
    if numQueriedChannels > 1
        for iLine = 1:numel(lineData)
            lineData{iLine} = reshape(lineData{iLine}, [], numQueriedChannels);
        end
    end
end

%% memmapfile fallback — pure MATLAB, no MEX required
function lineData = getSegmentedDataMmap(obj, lineStartIndices, lineNumElements, iChannel)
    nLines = numel(lineStartIndices);
    nCh    = obj.header.numChannels;
    nChReq = numel(iChannel);

    if ~strcmpi(obj.rawData.Format, 'int16')
        obj.rawData.Format = 'int16';
    end

    lineData = cell(nLines, 1);
    for k = 1:nLines
        spc  = lineNumElements(k) / nCh;
        base = lineStartIndices(k);
        d    = zeros(spc, nChReq, 'int16');
        for c = 1:nChReq
            s = base + spc * (iChannel(c) - 1);
            d(:, c) = obj.rawData.Data(s : s + spc - 1);
        end
        lineData{k} = d;
    end
end
