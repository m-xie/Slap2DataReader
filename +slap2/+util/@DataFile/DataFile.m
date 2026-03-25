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

            %% load data — uses memmapfile (no MEX required)
            obj.rawData = memmapfile(obj.datFileName, 'Format', 'int16');

            obj.loadFileHeader();
            obj.loadParsePlan();

            lineHeader = obj.getLineHeader(1, 1);
            obj.firstLineTimestamp = lineHeader.timestamp;
        end

        function delete(obj)
            obj.rawData = [];
        end
    end

    methods (Access = private)
        loadParsePlan(obj);
        loadFileHeader(obj);
    end

    methods
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
