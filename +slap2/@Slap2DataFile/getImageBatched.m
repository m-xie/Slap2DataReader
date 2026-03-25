function [imageData, imgNonNorm, freshness] = getImageBatched(obj,channelIdx,time,dt,zIdx,spTypeFlag)
    if nargin < 5 || isempty(zIdx)
        zIdx = 1;
    end
    if nargin < 6 || isempty(spTypeFlag)
        % spTypeFlag = 0 for all superpixels (both raster and integration)
        % spTypeFlag = 1 for raster only
        % spTypeFlag = 2 for integration (block) only
        spTypeFlag = 0;
    end

    assert(zIdx <= numel(obj.fastZs), 'Invalid zIdx: %d. Maximum zIdx: %d', zIdx, numel(obj.fastZs));
    assert(channelIdx <= obj.numChannels, ...
        'Invalid channelIdx: %d. Maximum channelIdx: %d',channelIdx,obj.numChannels);

    % time: the line number within the dataset at which to compute a frame
    % dt: the time window used for smoothing

    % could bound this better... 
    % The times to read are the greatest number of timepoints required to see every ROI twice
    dtRead = max(3 * dt, obj.hMultiDataFiles.header.linesPerCycle); 
    timeWindow = max(1, time - dtRead) : min(obj.hMultiDataFiles.totalNumLines, time + dtRead);

    lineIndices  = mod(timeWindow-1,obj.hMultiDataFiles.header.linesPerCycle)+1;
    cycleIndices = floor((timeWindow-1) / obj.hMultiDataFiles.header.linesPerCycle)+1;
    lineFastZIndices = obj.hMultiDataFiles.lineFastZIdxs(lineIndices);

    lineZMask = lineFastZIndices == zIdx;
    timeWindow = timeWindow(lineZMask);
    lineIndices  = lineIndices(lineZMask);
    cycleIndices = cycleIndices(lineZMask);

    weights = exp(-abs((time - timeWindow) / dt));

    % # rows x # columns x # channels
    FileHeader = obj.hMultiDataFiles.header;
    imageSize = double([FileHeader.dmdPixelsPerRow FileHeader.dmdPixelsPerColumn 2]);
    imageData = zeros(imageSize,'single');
    dataCount = zeros(imageSize,'single');

    % cell matrix of size (# lineIdxs x # channels)
    lineData = obj.hMultiDataFiles.getLineData(lineIndices, cycleIndices, channelIdx);
    for iLineIndex = 1:numel(lineIndices)
        lineIdx = lineIndices(iLineIndex);
        superPixelIds = obj.hMultiDataFiles.lineSuperPixelIDs{lineIdx};
        %superPixelIds = cellfun(@(sp)sp(1),superPixelIds)';
        superPixelIds = superPixelIds + 1;

        % note, could be a matrix for multiple channels
        % interleaved: (channels x line data)
        superPixelData = single(lineData{iLineIndex});

        superPixelIds = superPixelIds(:);
        superPixelData = superPixelData(:);

        % filter out minimum values and equate them to NaNs
        validSuperPixelMask = superPixelData > intmin('int16');
        superPixelIds = superPixelIds(validSuperPixelMask);
        superPixelData = superPixelData(validSuperPixelMask);

        weight = weights(iLineIndex);
        imageData(superPixelIds) = imageData(superPixelIds) + superPixelData .* weight;
        dataCount(superPixelIds) = dataCount(superPixelIds) + weight;
    end

    %imageData(dataCount==0) = NaN; not necessary(?) and eats a lot of time
    
    switch spTypeFlag
        case 1  % return raster only
            imgNonNorm = imageData(:,:,1)';

            imageData = imageData ./ dataCount;
            imageData = imageData(:,:,1)';

            if nargout>2 %compute 'freshness', how well-sampled each pixel is at this time
                %freshness = reshape(tmpF(1:prod(imageSize)),imageSize);
                freshness = dataCount(:,:,1)';
            end
        case 2  % return integration (block) only
            imgNonNorm = extractBlockImageOnly(imageData);

            imageData = imageData ./ dataCount;
            imageData = extractBlockImageOnly(imageData);

            if nargout>2 %compute 'freshness', how well-sampled each pixel is at this time
                %freshness = reshape(tmpF(1:prod(imageSize)),imageSize);
                freshness = extractBlockImageOnly(dataCount);
            end
        otherwise  % return all superpixels (both raster and integration)
            imgNonNorm = combineRasterAndBlockImages(imageData);
            
            imageData = imageData ./ dataCount;
        
            imageData = combineRasterAndBlockImages(imageData);
        
            if nargout>2 %compute 'freshness', how well-sampled each pixel is at this time
                %freshness = reshape(tmpF(1:prod(imageSize)),imageSize); % original (tmpF undefined)
                freshness = combineRasterAndBlockImages(dataCount);
            end
    end


    %%% Nested function
    function img = combineRasterAndBlockImages(data)
        bspm = obj.hMultiDataFiles.zPixelReplacementMapsNonRedundant{zIdx};
        if ~isempty(bspm)
            bspm = bspm + 1; % change from zero based indexing to one based indexing
            data(bspm(:,1)) = data(bspm(:,2));
        end

        rasterImg = data(:,:,1);
        blockImg  = data(:,:,2);

        blockImg_mask = ~isnan(blockImg);
        img = rasterImg;
        img(blockImg_mask) = blockImg(blockImg_mask);
        img = img';
    end

    function blockImg = extractBlockImageOnly(data)
        blockImg = nan(size(data,1:2));
        
        bspm = obj.hMultiDataFiles.zPixelReplacementMapsNonRedundant{zIdx};
        if ~isempty(bspm)
            bspm = bspm + 1; % change from zero based indexing to one based indexing
            blockImg(bspm(:,1)) = data(bspm(:,2));
        end
        blockImg  = blockImg';
    end
end
