function [deltaFOverF, dFFerr, tq] = getTimeSeries(obj, iChannel, iPixels, timeWindow)
%GETTIMESERIES Compute dF/F traces for a set of superpixels.
%   [dFF, dFFerr, tq] = obj.getTimeSeries(iChannel, iPixels, timeWindow)
%
%   iChannel   - scalar channel index (1-based)
%   iPixels    - vector of 1-based superpixel indices (or logical mask)
%   timeWindow - smoothing kernel width in lines
%
%   For each scan line whose superpixel set overlaps iPixels, data is read
%   across all cycles and accumulated into an exponential-weighted time
%   series.  F0 is estimated as the mean signal per superpixel.

    if islogical(iPixels)
        iPixels = find(iPixels);
    end
    iPixels = double(iPixels(:));

    FileHeader = obj.hMultiDataFiles.header;
    lpc  = FileHeader.linesPerCycle;
    nCyc = double(obj.hMultiDataFiles.numCycles);
    dt   = timeWindow / 2;
    nTS  = double(obj.hMultiDataFiles.totalNumLines);
    tq   = (0:dt:nTS)';
    nTq  = numel(tq);

    oAccum = zeros(nTq, 1);
    eAccum = zeros(nTq, 1);

    superPixelsPerLine = obj.hMultiDataFiles.lineSuperPixelIDs;

    fprintf('Computing superpixel traces (%d lines per cycle, %d cycles)...\n', lpc, nCyc);
    timerValue = tic;

    for iLine = 1:lpc
        lineSPids  = double(superPixelsPerLine{iLine}(:)) + 1;   % 0->1-based
        [~, locb]  = ismember(iPixels, lineSPids);
        positions  = locb(locb > 0);
        if isempty(positions)
            continue;
        end

        lineIdxVec  = repmat(iLine, nCyc, 1);
        cycleIdxVec = (1:nCyc)';
        allLineData = obj.hMultiDataFiles.getLineData(lineIdxVec, cycleIdxVec, iChannel);

        signals = zeros(nCyc, 1);
        for cyc = 1:nCyc
            vals = double(allLineData{cyc});
            signals(cyc) = sum(vals(positions, :), 'all');
        end

        meanSig     = mean(signals);
        globalLines = double((0:nCyc-1)') * lpc + iLine;

        for cyc = 1:nCyc
            gl   = globalLines(cyc);
            tqLo = max(1,   floor((gl - 6 * timeWindow) / dt) + 1);
            tqHi = min(nTq, ceil ((gl + 6 * timeWindow) / dt) + 1);
            idx  = tqLo:tqHi;
            w    = exp(-abs(tq(idx) - gl) / timeWindow);
            oAccum(idx) = oAccum(idx) + signals(cyc) .* w;
            eAccum(idx) = eAccum(idx) + meanSig      .* w;
        end

        if mod(iLine, max(1, round(lpc / 10))) == 0
            fprintf('  %d of %d lines...\n', iLine, lpc);
        end
    end

    fprintf('Done (%.1f s).\n', toc(timerValue));

    deltaFOverF = oAccum ./ max(eAccum, eps) - 1;
    % by construction of the SLAP2 deconvolution algorithm, 100 counts = 1 photon
    dFFerr = 100 * sqrt(max(1, oAccum ./ 100)) ./ max(eAccum, eps);
end
