classdef Bzip2
    %BZIP2 Portable bzip2 streams, implemented entirely in MATLAB.
    % The encoder uses fixed Huffman tables; the decoder accepts standard
    % variable tables, all block sizes, and concatenated streams.
    methods (Static)
        function output = compress(input)
            input = reshape(uint8(input),1,[]);
            parts = {kssolv.util.Bzip2.bits(hex2dec('425A6831'),32)};
            combined = uint32(0);
            for first = 1:80000:numel(input)
                block = input(first:min(first+79999,numel(input)));
                crc = kssolv.util.Bzip2.crc(block);
                combined = bitxor(kssolv.util.Bzip2.rotate(combined),crc);
                rle = kssolv.util.Bzip2.encodeRuns(block);
                [last,origin] = kssolv.util.Bzip2.forwardBwt(rle);
                alphabet = unique(last);
                tokens = kssolv.util.Bzip2.encodeMtf(last,alphabet);
                inUse = false(1,256); inUse(double(alphabet)+1) = true;
                groups = any(reshape(inUse,16,16),1);
                map = uint8(groups);
                for group = find(groups)
                    map = [map uint8(inUse((group-1)*16+(1:16)))]; %#ok<AGROW>
                end
                width = max(2,ceil(log2(numel(alphabet)+2)));
                selectors = ceil(numel(tokens)/50);
                lengths = [kssolv.util.Bzip2.bits(width,5) zeros(1,numel(alphabet)+2,'uint8')];
                parts{end+1} = [kssolv.util.Bzip2.magic('314159265359') ...
                    kssolv.util.Bzip2.bits(crc,32) uint8(0) ...
                    kssolv.util.Bzip2.bits(origin,24) map ...
                    kssolv.util.Bzip2.bits(2,3) ...
                    kssolv.util.Bzip2.bits(selectors,15) ...
                    zeros(1,selectors,'uint8') lengths lengths ...
                    kssolv.util.Bzip2.bits(tokens,width)]; %#ok<AGROW>
            end
            parts{end+1} = [kssolv.util.Bzip2.magic('177245385090') ...
                kssolv.util.Bzip2.bits(combined,32)];
            stream = [parts{:}];
            stream(end+1:ceil(numel(stream)/8)*8) = 0;
            output = uint8(double(reshape(stream,8,[])).' * (2.^(7:-1:0)).').';
        end

        function output = decompress(input)
            input = reshape(uint8(input),1,[]);
            pieces = {}; offset = 0;
            while offset < numel(input)
                [piece,consumed] = kssolv.util.Bzip2.decodeStream(input(offset+1:end));
                pieces{end+1} = piece; %#ok<AGROW>
                offset = offset + consumed;
            end
            if isempty(pieces), kssolv.util.Bzip2.invalid(); end
            output = reshape(uint8([pieces{:}]),1,[]);
        end
    end

    methods (Static, Access=private)
        function output = bits(value,width)
            values = uint32(value(:).');
            output = zeros(width,numel(value),'uint8');
            for position = 1:width
                output(position,:) = bitget(values,width-position+1);
            end
            output = reshape(output,1,[]);
        end

        function output = magic(value)
            output = [kssolv.util.Bzip2.bits(hex2dec(value(1:6)),24) ...
                kssolv.util.Bzip2.bits(hex2dec(value(7:12)),24)];
        end

        function value = rotate(value)
            value = bitor(bitshift(value,1),bitshift(value,-31));
        end

        function value = crc(bytes)
            persistent table
            if isempty(table)
                table = bitshift(uint32(0:255),24);
                for bit = 1:8
                    high = bitget(table,32) ~= 0;
                    table = bitshift(table,1);
                    table(high) = bitxor(table(high),uint32(hex2dec('04C11DB7')));
                end
            end
            value = uint32(hex2dec('FFFFFFFF'));
            for byte = bytes
                index = double(bitxor(bitshift(value,-24),uint32(byte)))+1;
                value = bitxor(bitshift(value,8),table(index));
            end
            value = bitcmp(value);
        end

        function output = encodeRuns(input)
            starts = [1 find(input(2:end) ~= input(1:end-1))+1];
            counts = diff([starts numel(input)+1]);
            output = zeros(1,ceil(numel(input)*1.25),'uint8'); cursor = 0;
            for index = 1:numel(starts)
                count = counts(index); byte = input(starts(index));
                while count > 0
                    part = min(count,255);
                    if part < 4
                        output(cursor+(1:part)) = byte; cursor = cursor+part;
                    else
                        output(cursor+(1:4)) = byte;
                        output(cursor+5) = uint8(part-4); cursor = cursor+5;
                    end
                    count = count-part;
                end
            end
            output = output(1:cursor);
        end

        function [last,origin] = forwardBwt(bytes)
            count = numel(bytes); ranks = uint32(bytes(:))+1; shift = 1;
            while true
                pairs = [ranks ranks(mod((0:count-1).'+shift,count)+1)];
                [sorted,order] = sortrows(pairs,[1 2]);
                groups = cumsum([1; any(sorted(2:end,:) ~= sorted(1:end-1,:),2)]);
                ranks(order) = uint32(groups);
                if groups(end) == count || shift >= count, break; end
                shift = shift*2;
            end
            last = reshape(bytes(mod(order-2,count)+1),1,[]);
            origin = find(order == 1,1)-1;
        end

        function tokens = encodeMtf(bytes,alphabet)
            list = alphabet; tokens = zeros(1,numel(bytes)+1,'uint16');
            cursor = 0; run = 0;
            for byte = bytes
                position = find(list == byte,1);
                if position == 1, run = run+1; continue; end
                flushRun();
                cursor = cursor+1; tokens(cursor) = uint16(position);
                list = [byte list(1:position-1) list(position+1:end)];
            end
            flushRun();
            cursor = cursor+1; tokens(cursor) = uint16(numel(alphabet)+1);
            tokens = tokens(1:cursor);
            function flushRun()
                if run == 0, return; end
                value = run-1;
                while true
                    cursor = cursor+1; tokens(cursor) = uint16(mod(value,2));
                    if value < 2, break; end
                    value = floor((value-2)/2);
                end
                run = 0;
            end
        end

        function [output,consumed] = decodeStream(input)
            if numel(input) < 14 || ~isequal(input(1:3),uint8('BZh')) ...
                    || input(4) < uint8('1') || input(4) > uint8('9')
                kssolv.util.Bzip2.invalid();
            end
            capacity = (double(input(4))-double('0'))*100000;
            stream = kssolv.util.Bzip2.bits(input,8); cursor = 33;
            combined = uint32(0); blocks = {}; weights = 2.^(31:-1:0);
            tables = {}; selectors = []; selection = 0; remaining = 0; active = [];
            while true
                high = read(24); low = read(24);
                if high == hex2dec('177245') && low == hex2dec('385090')
                    if uint32(read(32)) ~= combined, kssolv.util.Bzip2.invalid(); end
                    break
                end
                if high ~= hex2dec('314159') || low ~= hex2dec('265359')
                    kssolv.util.Bzip2.invalid();
                end
                checksum = uint32(read(32)); randomized = read(1); origin = read(24);
                groups = zeros(1,16); for i = 1:16, groups(i) = read(1); end
                used = false(1,256);
                for group = find(groups)
                    for i = 1:16, used((group-1)*16+i) = read(1); end
                end
                list = uint8(find(used)-1); alphabetSize = numel(list)+2;
                if isempty(list), kssolv.util.Bzip2.invalid(); end
                groupCount = read(3); selectorCount = read(15);
                if groupCount < 2 || groupCount > 6 || selectorCount < 1
                    kssolv.util.Bzip2.invalid();
                end
                selectorList = 1:groupCount; selectors = zeros(1,selectorCount);
                for i = 1:selectorCount
                    position = 1;
                    while read(1)
                        position = position+1;
                        if position > groupCount, kssolv.util.Bzip2.invalid(); end
                    end
                    selectors(i) = selectorList(position);
                    selectorList = [selectorList(position) selectorList(1:position-1) ...
                        selectorList(position+1:end)];
                end
                tables = cell(1,groupCount);
                for group = 1:groupCount
                    length = read(5); lengths = zeros(1,alphabetSize);
                    for i = 1:alphabetSize
                        while read(1)
                            if read(1), length = length-1; else, length = length+1; end
                            if length < 1 || length > 20, kssolv.util.Bzip2.invalid(); end
                        end
                        if length < 1 || length > 20, kssolv.util.Bzip2.invalid(); end
                        lengths(i) = length;
                    end
                    tables{group} = kssolv.util.Bzip2.huffman(lengths);
                end
                selection = 0; remaining = 0; last = zeros(1,capacity,'uint8'); count = 0;
                symbol = nextSymbol();
                while symbol ~= alphabetSize-1
                    if symbol <= 1
                        run = 0; power = 1;
                        while symbol <= 1
                            run = run+(symbol+1)*power; power = power*2;
                            if run > capacity-count, kssolv.util.Bzip2.invalid(); end
                            symbol = nextSymbol();
                        end
                        last(count+(1:run)) = list(1); count = count+run;
                        if symbol == alphabetSize-1, break; end
                    end
                    if symbol < 2 || symbol > numel(list) || count >= capacity
                        kssolv.util.Bzip2.invalid();
                    end
                    byte = list(symbol); count = count+1; last(count) = byte;
                    list = [byte list(1:symbol-1) list(symbol+1:end)];
                    symbol = nextSymbol();
                end
                if count == 0 || origin >= count, kssolv.util.Bzip2.invalid(); end
                last = last(1:count);
                [~,mapping] = sortrows([uint32(last(:)) uint32((1:count).')],[1 2]);
                position = mapping(origin+1); rle = zeros(1,count,'uint8');
                for i = 1:count
                    rle(i) = last(position); position = mapping(position);
                end
                if randomized, rle = kssolv.util.Bzip2.unrandomize(rle); end
                block = kssolv.util.Bzip2.decodeRuns(rle);
                if kssolv.util.Bzip2.crc(block) ~= checksum, kssolv.util.Bzip2.invalid(); end
                combined = bitxor(kssolv.util.Bzip2.rotate(combined),checksum);
                blocks{end+1} = block; %#ok<AGROW>
            end
            consumed = ceil((cursor-1)/8); output = reshape(uint8([blocks{:}]),1,[]);

            function value = read(width)
                if cursor+width-1 > numel(stream), kssolv.util.Bzip2.invalid(); end
                value = double(stream(cursor:cursor+width-1))*weights(33-width:32).';
                cursor = cursor+width;
            end

            function symbol = nextSymbol()
                if remaining == 0
                    selection = selection+1;
                    if selection > numel(selectors), kssolv.util.Bzip2.invalid(); end
                    active = tables{selectors(selection)}; remaining = 50;
                end
                available = min(active.width,numel(stream)-cursor+1);
                if available <= 0, kssolv.util.Bzip2.invalid(); end
                index = double(stream(cursor:cursor+available-1))*weights(33-available:32).';
                index = index*2^(active.width-available)+1;
                length = double(active.lengths(index));
                if length == 0 || length > available, kssolv.util.Bzip2.invalid(); end
                symbol = double(active.symbols(index))-1;
                cursor = cursor+length; remaining = remaining-1;
            end
        end

        function table = huffman(lengths)
            width = max(lengths);
            symbols = zeros(1,2^width,'uint16'); sizes = zeros(1,2^width,'uint8');
            code = 0;
            for length = 1:width
                for symbol = find(lengths == length)
                    if code >= 2^length, kssolv.util.Bzip2.invalid(); end
                    indices = code*2^(width-length)+(1:2^(width-length));
                    symbols(indices) = uint16(symbol); sizes(indices) = uint8(length);
                    code = code+1;
                end
                code = code*2;
            end
            table = struct('width',width,'symbols',symbols,'lengths',sizes);
        end

        function output = decodeRuns(input)
            count = numel(input); output = zeros(1,count,'uint8'); cursor = 1; written = 0;
            if count >= 4
                same = input(2:end) == input(1:end-1);
                candidates = find(conv(double(same),[1 1 1],'valid') == 3);
            else
                candidates = [];
            end
            for first = candidates
                if first < cursor, continue; end
                if first+4 > count, kssolv.util.Bzip2.invalid(); end
                literal = first-cursor;
                output(written+(1:literal)) = input(cursor:first-1); written = written+literal;
                run = 4+double(input(first+4));
                output(written+(1:run)) = input(first); written = written+run;
                cursor = first+5;
            end
            literal = count-cursor+1;
            output(written+(1:literal)) = input(cursor:end); written = written+literal;
            output = output(1:written);
        end

        function output = unrandomize(input)
            % Legacy randomized blocks (bzip2 0.9.0). The compatibility table
            % is derived from libbzip2; see bzip2-LICENSE.txt.
            numbers = kssolv.util.Bzip2.randomizationTable();
            output = input; remaining = 0; position = 0;
            for i = 1:numel(input)
                if remaining == 0
                    position = mod(position,512)+1; remaining = numbers(position);
                end
                remaining = remaining-1;
                if remaining == 1, output(i) = bitxor(output(i),uint8(1)); end
            end
        end

        function numbers = randomizationTable()
            numbers = [ ...
                619 720 127 481 931 816 813 233 566 247 985 724 205 454 863 491 ...
                741 242 949 214 733 859 335 708 621 574 73 654 730 472 419 436 ...
                278 496 867 210 399 680 480 51 878 465 811 169 869 675 611 697 ...
                867 561 862 687 507 283 482 129 807 591 733 623 150 238 59 379 ...
                684 877 625 169 643 105 170 607 520 932 727 476 693 425 174 647 ...
                73 122 335 530 442 853 695 249 445 515 909 545 703 919 874 474 ...
                882 500 594 612 641 801 220 162 819 984 589 513 495 799 161 604 ...
                958 533 221 400 386 867 600 782 382 596 414 171 516 375 682 485 ...
                911 276 98 553 163 354 666 933 424 341 533 870 227 730 475 186 ...
                263 647 537 686 600 224 469 68 770 919 190 373 294 822 808 206 ...
                184 943 795 384 383 461 404 758 839 887 715 67 618 276 204 918 ...
                873 777 604 560 951 160 578 722 79 804 96 409 713 940 652 934 ...
                970 447 318 353 859 672 112 785 645 863 803 350 139 93 354 99 ...
                820 908 609 772 154 274 580 184 79 626 630 742 653 282 762 623 ...
                680 81 927 626 789 125 411 521 938 300 821 78 343 175 128 250 ...
                170 774 972 275 999 639 495 78 352 126 857 956 358 619 580 124 ...
                737 594 701 612 669 112 134 694 363 992 809 743 168 974 944 375 ...
                748 52 600 747 642 182 862 81 344 805 988 739 511 655 814 334 ...
                249 515 897 955 664 981 649 113 974 459 893 228 433 837 553 268 ...
                926 240 102 654 459 51 686 754 806 760 493 403 415 394 687 700 ...
                946 670 656 610 738 392 760 799 887 653 978 321 576 617 626 502 ...
                894 679 243 440 680 879 194 572 640 724 926 56 204 700 707 151 ...
                457 449 797 195 791 558 945 679 297 59 87 824 713 663 412 693 ...
                342 606 134 108 571 364 631 212 174 643 304 329 343 97 430 751 ...
                497 314 983 374 822 928 140 206 73 263 980 736 876 478 430 305 ...
                170 514 364 692 829 82 855 953 676 246 369 970 294 750 807 827 ...
                150 790 288 923 804 378 215 828 592 281 565 555 710 82 896 831 ...
                547 261 524 462 293 465 502 56 661 821 976 991 658 869 905 758 ...
                745 193 768 550 608 933 378 286 215 979 792 961 61 688 793 644 ...
                986 403 106 366 905 644 372 567 466 434 645 210 389 550 919 135 ...
                780 773 635 389 707 100 626 958 165 504 920 176 193 713 857 265 ...
                203 50 668 108 645 990 626 197 510 357 358 850 858 364 936 638 ...
                ];
        end

        function invalid()
            error('KSSOLV:Compression:Data','Invalid, truncated, or corrupted bzip2 stream.');
        end
    end
end
