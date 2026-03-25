function lineData = getLineData(obj, lineIndices, cycleIndices, iChannel)
%GETLINEDATA Read raw int16 line payloads (pure MATLAB, no MEX).
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

    assert(~obj.header.channelsInterleave, 'Only deinterleaved data is supported');

    cycleOffset      = (cycleIndices - 1) * obj.header.bytesPerCycle / 2;
    lineStartIndices = obj.lineDataStartIdxs(lineIndices) + cycleOffset;
    lineNumElements  = obj.lineDataNumElements(lineIndices);

    nLines  = numel(lineIndices);
    nCh     = obj.header.numChannels;
    nChReq  = numel(iChannel);

    if ~strcmpi(obj.rawData.Format, 'int16')
        obj.rawData.Format = 'int16';
    end

    lineData = cell(nLines, 1);
    for k = 1:nLines
        spc  = lineNumElements(k) / nCh;      % samples per channel
        base = lineStartIndices(k);            % 1-based int16 index
        d    = zeros(spc, nChReq, 'int16');
        for c = 1:nChReq
            s = base + spc * (iChannel(c) - 1);
            d(:, c) = obj.rawData.Data(s : s + spc - 1);
        end
        lineData{k} = d;
    end
end
