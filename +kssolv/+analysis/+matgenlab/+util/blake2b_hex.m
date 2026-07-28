function output=blake2b_hex(input,digest_size)
%BLAKE2B_HEX Pure-MATLAB unkeyed BLAKE2b hexadecimal digest.
if nargin<2,digest_size=16;end
if digest_size<1||digest_size>64||digest_size~=fix(digest_size)
    error("KSSOLV:Matgenlab:GraphHash:DigestSize", ...
        "BLAKE2b digest_size must be an integer from 1 through 64.");
end
bytes=unicode2native(char(string(input)),"UTF-8");
iv=[u64("6a09e667","f3bcc908"),u64("bb67ae85","84caa73b"), ...
    u64("3c6ef372","fe94f82b"),u64("a54ff53a","5f1d36f1"), ...
    u64("510e527f","ade682d1"),u64("9b05688c","2b3e6c1f"), ...
    u64("1f83d9ab","fb41bd6b"),u64("5be0cd19","137e2179")];
h=iv;h(1)=bitxor(h(1),uint64(hex2dec("01010000")+digest_size));
sigma=[ ...
     1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16
    15 11  5  9 10 16 14  7  2 13  1  3 12  8  6  4
    12  9 13  1  6  3 16 14 11 15  4  7  8  2 10  5
     8 10  4  2 14 13 12 15  3  7  6 11  5  1 16  9
    10  1  6  8  3  5 11 16 15  2 12 13  7  9  4 14
     3 13  7 11  1 12  9  4  5 14  8  6 16 15  2 10
    13  6  2 16 15 14  5 11  1  8  7  4 10  3  9 12
    14 12  8 15 13  2  4 10  6  1 16  5  9  7  3 11
     7 16 15 10 12  4  1  9 13  3 14  8  2  5 11  6
    11  3  9  5  8  7  2  6 16 12 10 15  4 13 14  1];
sigma=[sigma;sigma(1:2,:)];
blockCount=max(1,ceil(numel(bytes)/128));
for blockIndex=1:blockCount
    first=(blockIndex-1)*128+1;last=min(blockIndex*128,numel(bytes));
    block=zeros(1,128,"uint8");
    if first<=numel(bytes),block(1:last-first+1)=bytes(first:last);end
    count=uint64(last);isLast=blockIndex==blockCount;
    h=compress(h,block,count,isLast,iv,sigma);
end
digest=zeros(1,64,"uint8");
for ii=1:8
    word=h(ii);
    for jj=0:7
        digest((ii-1)*8+jj+1)=uint8(bitand(bitshift(word,-8*jj),255));
    end
end
output=string(lower(reshape(dec2hex(digest(1:digest_size),2).',1,[])));
end

function h=compress(h,block,count,isLast,iv,sigma)
m=zeros(1,16,"uint64");
for ii=1:16
    word=uint64(0);
    for jj=0:7
        word=bitor(word,bitshift(uint64(block((ii-1)*8+jj+1)),8*jj));
    end
    m(ii)=word;
end
v=[h,iv];v(13)=bitxor(v(13),count);
if isLast,v(15)=bitcmp(v(15));end
for round=1:12
    s=sigma(round,:);
    v=G(v,1,5,9,13,m(s(1)),m(s(2)));
    v=G(v,2,6,10,14,m(s(3)),m(s(4)));
    v=G(v,3,7,11,15,m(s(5)),m(s(6)));
    v=G(v,4,8,12,16,m(s(7)),m(s(8)));
    v=G(v,1,6,11,16,m(s(9)),m(s(10)));
    v=G(v,2,7,12,13,m(s(11)),m(s(12)));
    v=G(v,3,8,9,14,m(s(13)),m(s(14)));
    v=G(v,4,5,10,15,m(s(15)),m(s(16)));
end
for ii=1:8,h(ii)=bitxor(h(ii),bitxor(v(ii),v(ii+8)));end
end
function v=G(v,a,b,c,d,x,y)
v(a)=add64(add64(v(a),v(b)),x);v(d)=rotr(bitxor(v(d),v(a)),32);
v(c)=add64(v(c),v(d));v(b)=rotr(bitxor(v(b),v(c)),24);
v(a)=add64(add64(v(a),v(b)),y);v(d)=rotr(bitxor(v(d),v(a)),16);
v(c)=add64(v(c),v(d));v(b)=rotr(bitxor(v(b),v(c)),63);
end
function value=add64(a,b)
mask=uint64(4294967295);
lo=double(bitand(a,mask))+double(bitand(b,mask));
carry=floor(lo/4294967296);lo=mod(lo,4294967296);
hi=mod(double(bitshift(a,-32))+double(bitshift(b,-32))+carry,4294967296);
value=bitor(bitshift(uint64(hi),32),uint64(lo));
end
function value=rotr(x,n)
if n==0,value=x;else,value=bitor(bitshift(x,-n),bitshift(x,64-n));end
end
function value=u64(high,low)
value=bitor(bitshift(uint64(hex2dec(high)),32),uint64(hex2dec(low)));
end
