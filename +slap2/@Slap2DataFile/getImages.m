function [imageData, dataCount] = getImages(obj,channelIdxs,times,dt,zIdx,spTypeFlag)
% times: the line numbers within the dataset at which to compute a frame
% dt: the time window used for smoothing

%to do:
%Support multichannel read
%questions for Georg:
%has this been done already?
%trouble with parallelization (only one metadata file can be open at a
%time?)


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
assert(all(channelIdxs <= obj.numChannels), ...
    'Invalid channelIdx: %d. Maximum channelIdx: %d',channelIdxs,obj.numChannels);

nFrames = numel(times);
nChannels = numel(channelIdxs);
dtRead = max(3 * dt, obj.hMultiDataFiles.header.linesPerCycle);

timeLogical = false(1, max(times) + dtRead);
for tix = 1:length(times)
    t = times(tix);
    timeLogical(max(1, t - dtRead):min(obj.hMultiDataFiles.totalNumLines, t + dtRead)) = true;
end
lineTimes = find(timeLogical);

%timeWindow = max(1, min(times) - dtRead) : min(obj.hMultiDataFiles.totalNumLines, max(times) + dtRead);
%remove any times not

lineIndices  = mod(lineTimes-1,obj.hMultiDataFiles.header.linesPerCycle)+1;
cycleIndices = floor((lineTimes-1) / obj.hMultiDataFiles.header.linesPerCycle)+1;
lineFastZIndices = obj.hMultiDataFiles.lineFastZIdxs(lineIndices);

lineZMask = lineFastZIndices == zIdx;
lineTimes = lineTimes(lineZMask);
lineIndices  = lineIndices(lineZMask);
cycleIndices = cycleIndices(lineZMask);

% # rows x # columns x # channels
FileHeader = obj.hMultiDataFiles.header;
imageData = zeros(double([FileHeader.dmdPixelsPerRow*FileHeader.dmdPixelsPerColumn nChannels nFrames]),'single');
dataCount = zeros(double([FileHeader.dmdPixelsPerRow*FileHeader.dmdPixelsPerColumn 1 nFrames]),'single');

% cell matrix of size (# lineIdxs x # channels)
lineData = obj.hMultiDataFiles.getLineData(lineIndices, cycleIndices, channelIdxs);
for iLineIndex = 1:numel(lineIndices)
    lineIdx = lineIndices(iLineIndex);
    superPixelIds = obj.hMultiDataFiles.lineSuperPixelIDs{lineIdx};
    superPixelIds = superPixelIds + 1;

    % note, could be a matrix for multiple channels
    % interleaved: (channels x line data)
    superPixelData = single(lineData{iLineIndex});

    % superPixelIds = superPixelIds(:);
    % superPixelData = superPixelData(:);
    % 
    % % filter out minimum values and equate them to NaNs
    % validSuperPixelMask = superPixelData > intmin('int16');
    % superPixelIds = superPixelIds(validSuperPixelMask);
    % superPixelData = superPixelData(validSuperPixelMask);

    lineTime = lineTimes(iLineIndex);
    framesToUpdate = find(abs(times-lineTime)<dtRead);
    weights = reshape(exp(-abs((times(framesToUpdate) - lineTime) ./ dt)), 1, 1, []);

    imageData(superPixelIds, :, framesToUpdate) = imageData(superPixelIds, :, framesToUpdate) + superPixelData .* weights;
    dataCount(superPixelIds, 1, framesToUpdate) = dataCount(superPixelIds, 1, framesToUpdate) + weights;
end

%imageData(dataCount==0) = NaN; not necessary(?) and eats a lot of time

switch spTypeFlag
    case 1  % return raster only
        %imgNonNorm = imageData(:,:,1)';

        imageData = imageData ./ dataCount;
        imageData = permute(reshape(imageData, FileHeader.dmdPixelsPerRow, FileHeader.dmdPixelsPerColumn, nChannels, nFrames), [2 1 3 4]);
        
        if nargout>1 %compute 'freshness', how well-sampled each pixel is at this time
            %freshness = reshape(tmpF(1:prod(imageSize)),imageSize);
            dataCount = permute(reshape(dataCount, FileHeader.dmdPixelsPerRow, FileHeader.dmdPixelsPerColumn,  1, nFrames), [2 1 3 4]);
        end
    case 2  % return integration (block) only
        %imgNonNorm = extractBlockImageOnly(imageData);

        imageData = imageData ./ dataCount;
        imageData = extractBlockImageOnly(imageData);

        if nargout>1 %compute 'freshness', how well-sampled each pixel is at this time
            dataCount = extractBlockImageOnly(dataCount);
        end
    otherwise  % return all superpixels (both raster and integration)
        %imgNonNorm = combineRasterAndBlockImages(imageData);

        imageData = imageData ./ dataCount;

        imageData = combineRasterAndBlockImages(imageData);

        if nargout>1 %compute 'freshness', how well-sampled each pixel is at this time
            error('freshness not implemented yet for combined images')
            %freshness = combineRasterAndBlockImages(freshness);
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
