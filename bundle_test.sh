BLOB_PREFIX=Blob_
f=media/bmp/bg.bmp
echo "\
	.global $BLOB_PREFIX$m
	.section .rdata
$BLOB_PREFIX$m:
	.int data2 - data1
data1:
	.incbin \"$f\"
data2:
	" | gcc -c -xassembler - -o c:/1/test.o
