classdef DataFile < handle
    properties (Constant, Hidden)
        MAGIC_NUMBER = uint32(322379495);
    end

    properties
        filename char = '';
        metaDataFileName char = '';
        datFileName char = '';
        rawData = [];
        metaData = [];
    end

    properties
        header
        numCycles
        lineHeaderIdxs;
        lineDataStartIdxs;
        lineDataNumElements;
        fastZs
        lineSuperPixelIDs
        lineSuperPixelZIdxs
        lineNumSuperPixels
        zPixelReplacementMaps
        zPixelReplacementMapsNonRedundant
        lineFastZIdxs
        totalNumLines
        numChannels
        firstLineTimestamp (1,1) uint64 = 0;
    end

    properties (Hidden, SetAccess = private)
        StreamId {mustBeScalarOrEmpty};
        useMex (1,1) logical = false;
    end

    methods
        function obj = DataFile(filename)
            arguments
                filename (1,:) char = '';
            end

            if isempty(filename)
                [fn, pn, ~] = uigetfile('*.dat', 'Open Data File');
                assert(~isnumeric(fn), 'No file selected.');
                filename = fullfile(pn, fn);
            end

            obj.filename = filename;
            assert(isfile(obj.filename), 'File not found: %s', obj.filename);

            [p,n] = fileparts(filename);
            n_base = regexprep(n,'-TRIAL[0-9]+','','ignorecase');
            n_base = regexprep(n_base,'-CYCLE-?[0-9]+$','','ignorecase');

            obj.metaDataFileName = fullfile(p, [n_base '.meta']);
            assert(isfile(obj.metaDataFileName), ...
                'Metadata file not found: %s', obj.metaDataFileName);

            obj.datFileName = fullfile(p,[n '.dat']);
            assert(isfile(obj.datFileName), ...
                'Data file not found: %s', obj.datFileName);

            obj.metaData = load(obj.metaDataFileName, '-mat');

            %% load data
            if ~isempty(which('MexFetchImageData'))
                obj.StreamId = MexFetchImageData('OPEN', obj.datFileName);
                obj.useMex = true;
            end
            obj.rawData = memmapfile(obj.datFileName, 'Format', 'int16');

            obj.loadFileHeader();
            obj.loadParsePlan();

            lineHeader = obj.getLineHeader(1, 1);
            obj.firstLineTimestamp = lineHeader.timestamp;
        end

        function delete(obj)
            if obj.useMex && ~isempty(obj.StreamId)
                MexFetchImageData('CLOSE', obj.StreamId);
            end
            obj.rawData = [];
        end
    end

    methods (Access = private)
        loadParsePlan(obj);
        loadFileHeader(obj);
    end

    methods
        function checkFileIntegrity(obj, iLines, iCycles)
            arguments
                obj {mustBeScalarOrEmpty, mustBeNonempty};
                iLines (:, 1) {mustBeInteger, mustBeNonnegative} = 1:obj.header.linesPerCycle;
                iCycles (:, 1) {mustBeInteger, mustBeNonnegative} = 1:obj.numCycles;
            end

            assert(obj.useMex, 'SLAP2:DataFile:checkFileIntegrity requires MexFetchImageData');

            if islogical(iLines)
                validateattributes(iLines, {'logical'}, {'numel', length(obj.lineHeaderIdxs)}, ...
                    [mfilename('class'), '.checkFileIntegrity'], 'iLines');
                iLines = find(iLines);
            else
                validateattributes(iLines, {'numeric'}, {'<=', length(obj.lineHeaderIdxs)}, ...
                    [mfilename('class'), '.checkFileIntegrity'], 'iLines');
            end

            cycleOffsets = (iCycles - 1) * obj.header.bytesPerCycle / 2;
            lineOffsets = obj.lineHeaderIdxs(iLines) - 1;
            headerOffsets = lineOffsets + (cycleOffsets .') + 2; % sample offset of 2

            magicNumberValues = MexFetchImageData( ...
                'GETDATA' ...
                , obj.StreamId ...
                , uint64([headerOffsets(:), repmat(2, numel(headerOffsets), 1)]) ...
            );
            magic_numbers = typecast(cell2mat(magicNumberValues), 'uint32');
            assert(all(magic_numbers == obj.MAGIC_NUMBER), 'Data corruption detected');
        end

        function [lineDataStartIdx, lineDataNumElements] = getLineDataIdxs(obj, lineIdx, cycleIdx)
            if nargin < 3 || isempty(cycleIdx)
                cycleIdx = floor((lineIdx - 1) / obj.header.linesPerCycle) + 1;
                lineIdx = mod(lineIdx - 1, obj.header.linesPerCycle) + 1;
            end

            cycleOffset = (cycleIdx - 1) * obj.header.bytesPerCycle / 2;
            lineDataStartIdx = obj.lineDataStartIdxs(lineIdx) + cycleOffset;
            lineDataNumElements = obj.lineDataNumElements(lineIdx);
        end

        lineData = getLineData(obj, lineIndices, cycleIndices, iChannel);
        lineHeader = getLineHeader(obj, lineIdx, cycleIdx);
    end

    methods (Static)
        lineHeader = parseLineHeader(data,fpgaSystemClock_Hz,referenceTimestamp,fpgaTimeReference);
    end
end
